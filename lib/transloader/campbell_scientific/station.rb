require "csv"
require "time"

require_relative "../data_file"
require_relative "../station"
require_relative "../station_methods"

module Transloader
  # Class for downloading and uploading metadata and observation data
  # from Campbell Scientific's sensor data portal. The data is
  # downloaded over HTTP, and the data use the TOA5 format.
  class CampbellScientificStation < Station
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    LONG_NAME     = "Campbell Scientific Weather Station"
    NAME          = "Campbell Scientific Station"
    PROVIDER_ID   = "CampbellScientific"
    PROVIDER_NAME = "campbell_scientific"

    attr_reader :id, :metadata, :properties, :store

    def initialize(options = {})
      @http_client = options[:http_client]
      @id          = options[:id]
      @store       = StationStore.new({
        provider:     PROVIDER_NAME,
        station:      @id,
        database_url: options[:database_url]
      })
      @metadata    = @store.metadata
      @metadata[:properties] ||= {}
      properties  = options[:properties] || {}
      @metadata[:properties].merge!(properties)
    end

    # Download and extract metadata from HTML, use to build metadata
    # needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the
    # downloaded metadata before being cached.
    def download_metadata(override_metadata: {})
      properties = @metadata[:properties]
      # Check for data files
      data_urls = properties[:data_urls]

      if data_urls.empty?
        raise Error, "No data URLs specified. Data URLs are required to download station metadata."
      end

      data_files = []
      datastreams = []

      data_urls.each do |data_url|
        # Download CSV
        response = @http_client.get(uri: data_url)

        # Incorrect URLs triggers a 302 Found that redirects to the 404
        # page, we need to catch that here.
        if response["Location"] == "http://dataservices.campbellsci.ca/404.html"
          raise HTTPError.new(response, "Incorrect Data URL for #{NAME}")
        elsif response.code == "301"
          # Follow permanent redirects
          response = @http_client.get(uri: response["Location"])
        end

        filedata = response.body
        doc      = Transloader::TOA5Document.new(filedata)

        # Store CSV file metadata
        #
        # Cannot use "Content-Length" here as the request has been
        # encoded by gzip, which is enabled by default for Ruby
        # net/http.
        last_modified = parse_last_modified(response["Last-Modified"])
        data_files.push(DataFile.new({
          url:           data_url,
          last_modified: to_iso8601(last_modified),
          length:        filedata.length
        }).to_h)

        # Parse CSV headers for station metadata
        #
        # Row 1:
        # 1. File Type
        # 2. Station Name
        # 3. Model Name
        # 4. Serial Number
        # 5. Logger OS Version
        # 6. Logger Program
        # 7. Logger Program Signature
        # 8. Table Name
        #
        # Note: It is possible that different files may have different
        # station metadata values. We are assuming that all data files
        # are from the same station/location and that the values are not
        # different between data files.
        properties[:station_model_name]    = doc.metadata(:station_name)
        properties[:station_serial_number] = doc.metadata(:datalogger_serial_number)
        properties[:station_program]       = doc.metadata(:datalogger_program_name)

        # Create datastreams from column headers.
        # Skip the first column header for timestamp.
        doc.headers.slice(1..-1).each do |header|
          datastreams.push(header)
        end
      end

      # Reduce datastreams to unique entries, as multiple data files
      # *may* share the same properties
      datastreams.uniq! do |datastream|
        datastream[:name]
      end

      logger.warn "Latitude and Longitude unavailable from metadata."
      logger.warn "These values must be manually added to the station metadata file."

      logger.warn "Time zone offset not available from data source."
      logger.warn "The offset must be manually added to the station metadata file."

      logger.warn "Sensor metadata PDF or SensorML not available from data source."
      logger.warn "The URL may be manually added to the station metadata file under the \"procedure\" key."

      # Convert to Hash
      @metadata.merge!({
        name:            "#{NAME} #{@id}",
        description:     "#{LONG_NAME} #{@id}",
        latitude:        nil,
        longitude:       nil,
        elevation:       nil,
        timezone_offset: nil,
        updated_at:      Time.now.utc,
        procedure:       nil,
        datastreams:     datastreams,
        data_files:      data_files,
        properties:      properties
      })

      if !override_metadata.nil?
        @metadata.merge!(override_metadata)
      end

      save_metadata
    end

    # Upload metadata to SensorThings API.
    # * server_url: URL endpoint of SensorThings API
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will be
    #              uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              be uploaded to STA.
    #
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_metadata(server_url, options = {})
      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

      # THING entity
      # Create Thing entity
      thing = build_thing({
        provider:              'Campbell Scientific',
        station_id:            @id,
        station_model_name:    @metadata[:properties][:station_model_name],
        station_serial_number: @metadata[:properties][:station_serial_number],
        station_program:       @metadata[:properties][:station_program]
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:"Thing@iot.navigationLink"] = thing.link
      save_metadata

      # LOCATION entity
      # Check if latitude or longitude are blank
      if @metadata[:latitude].nil? || @metadata[:longitude].nil?
        raise Error, "Station latitude or longitude is nil! Location entity cannot be created."
      end

      # Create Location entity
      location = build_location()

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:"Location@iot.navigationLink"] = location.link
      save_metadata

      # SENSOR entities
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = build_sensor("#{NAME} #{@id} #{stream[:name]} Sensor")

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:"Sensor@iot.navigationLink"] = sensor.link
        stream[:"Sensor@iot.id"] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      datastreams.each do |stream|
        # Create an Observed Property based on the datastream, using the
        # Ontology if available.
        observed_property = build_observed_property(stream[:name])

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream[:"ObservedProperty@iot.navigationLink"] = observed_property.link
        stream[:"ObservedProperty@iot.id"] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        datastream_name  = stream[:name]

        datastream = entity_factory.new_datastream({
          name:              "#{NAME} #{@id} #{datastream_name}",
          description:       "#{NAME} #{@id} #{datastream_name}",
          unitOfMeasurement: uom_for_datastream(datastream_name, stream[:Units]),
          observationType:   observation_type_for(datastream_name),
          Sensor:            {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty:  {
            '@iot.id' => stream[:'ObservedProperty@iot.id']
          }
        })

        # Upload entity and parse response
        datastream.upload_to(thing.link)

        # Cache URL
        stream[:"Datastream@iot.navigationLink"] = datastream.link
        stream[:"Datastream@iot.id"] = datastream.id
      end

      save_metadata
    end

    # Save the observations to file cache.
    # Interval download does nothing as there is no way to currently
    # extract a range from the Campbell Scientific data files.
    def download_observations(interval = nil)
      if !interval.nil?
        logger.warn "Interval download for observations is unsupported for Campbell Scientific"
      end

      @metadata[:data_files].each do |data_file|
        data_filename = data_file[:filename]
        all_observations = download_observations_for_file(data_file).sort_by { |obs| obs[0] }

        # Collect datastream names for comparisons.
        # A Set is used for fast lookups and unique values.
        datastream_names = datastream_names_set(@metadata[:datastreams])

        # Store Observations in DataStore.
        observations = convert_to_store_observations(all_observations, datastream_names)
        logger.info "Loaded Observations: #{observations.length}"
        @store.store_data(observations)
      end
    end

    # Collect all the observation files in the date interval, and upload
    # them.
    #
    # * destination: URL endpoint of SensorThings API
    # * interval: ISO8601 <start>/<end> interval
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will have
    #              observations uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              have observations be uploaded to STA.
    #
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_observations(destination, interval, options = {})
      time_interval = Transloader::TimeInterval.new(interval)
      observations  = @store.get_data_in_range(time_interval.start, time_interval.end)
      logger.info "Uploading Observations: #{observations.length}"
      upload_observations_array(observations, options)
    end



    # For parsing functionality specific to this data provider
    private

    # Connect to data provider and download Observations for a specific
    # data_file entry.
    #
    # Return an array of observation rows:
    # [
    #   ["2019-03-05T17:00:00.000Z", {
    #     name: "TEMPERATURE_Avg",
    #     reading: 5.479
    #   }, {
    #     name: "WIND_SPEED",
    #     reading: 12.02
    #   }],
    #   ["2019-03-05T18:00:00.000Z", {
    #   ...
    #   }]
    # ]
    def download_observations_for_file(data_file)
      download = partial_download_url(
        url: data_file[:url],
        offset: data_file[:last_length])

      doc          = nil
      observations = []

      # If full file was downloaded, parse from beginning. Otherwise
      # only parse extract of file.
      if download[:body] && download[:full_file]
        doc = Transloader::TOA5Document.new(download[:body])
        column_headers = doc.headers.slice(1..-1).map do |x|
          x[:name]
        end

        # Store column names in station metadata cache file, as
        # partial requests later will not be able to know the column
        # headers.
        data_file[:headers] = column_headers
        save_metadata
      elsif download[:body]
        # TODO: Improve parsing by excluding partial rows
        begin
          doc = Transloader::TOA5Document.new(download[:body])
        rescue CSV::MalformedCSVError => e
          logger.error "Could not parse partial response data.", e
        end
      end

      # Update station metadata cache with what the server says is the
      # latest file update time and the latest file length in bytes
      data_file[:last_modified] = to_iso8601(download[:last_modified])
      data_file[:last_length]   = download[:content_length]
      save_metadata

      # Parse observations from CSV
      doc && doc.rows.each do |row|
        # Transform dates into ISO8601 in UTC.
        # This will make it simpler to group them by day and to simplify
        # timezones for multiple stations.
        timestamp = parse_toa5_timestamp(row[0], @metadata[:timezone_offset])
        utc_time = to_iso8601(timestamp)
        observations.push([utc_time,
          row[1..-1].map.with_index { |x, i|
            {
              name: data_file[:headers][i],
              reading: parse_reading(x)
            }
          }
        ])
      end

      observations
    end

    # Parse an observation reading from the data source, converting a
    # string to a float or if null (i.e. "NAN") then use STA compatible
    # "null" string.
    # "NAN" usage here is specific to Campbell Scientific loggers.
    def parse_reading(reading)
      reading == "NAN" ? "null" : reading.to_f
    end
  end
end
