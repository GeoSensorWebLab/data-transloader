require 'csv'
require 'time'
require 'transloader/station_methods'

module Transloader
  class CampbellScientificStation
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    attr_accessor :id, :metadata, :properties, :provider

    def initialize(options = {})
      @data_store        = options[:data_store]
      @http_client       = options[:http_client]
      @id                = options[:id]
      @metadata_store    = options[:metadata_store]
      @provider          = options[:provider]
      @properties        = options[:properties]
      @metadata          = {}
      @ontology          = CampbellScientificOntology.new
      @entity_factory    = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the 
    # downloaded metadata before being cached.
    def download_metadata(override_metadata: {}, overwrite: false)
      if (@metadata_store.metadata != {} && !overwrite)
        logger.warn "Existing metadata found, will not overwrite."
        return false
      end

      # Check for data files
      data_urls = @properties[:data_urls]

      if data_urls.empty?
        raise "No data URLs specified. Data URLs are required to download station metadata."
      end

      data_files = []
      datastreams = []

      data_urls.each do |data_url|
        # Download CSV
        response = @http_client.get(uri: data_url)

        # Incorrect URLs triggers a 302 Found that redirects to the 404 
        # page, we need to catch that here.
        if response["Location"] == "http://dataservices.campbellsci.ca/404.html"
          raise "Not Found: #{data_url}"
        end

        filedata = response.body
        data = CSV.parse(filedata)
        
        # Store CSV file metadata
        # 
        # Cannot use "Content-Length" here as the request has been
        # encoded by gzip, which is enabled by default for Ruby 
        # net/http.
        last_modified = parse_last_modified(response["Last-Modified"])
        data_files.push({
          filename:       File.basename(data_url),
          url:            data_url,
          last_modified:  to_iso8601(last_modified),
          initial_length: filedata.length
        })

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
        @properties[:station_model_name]    = data[0][2]
        @properties[:station_serial_number] = data[0][3]
        @properties[:station_program]       = data[0][5]

        # Parse CSV column headers for datastreams, units
        # 
        # Row 2:
        # 1. Timestamp
        # 2+ (Observed Property)
        # Row 3:
        # Unit or Data Type
        # Row 4:
        # Observation Type (peak value, average value)
        # (WVc is Wind Vector Cell, probably)
        data[1].slice(1..-1).each_with_index do |col, index|
          datastreams.push({
            name: col,
            units: data[2][1+index],
            type: data[3][1+index]
          })
        end
      end

      # TODO: Reduce datastreams to unique entries, as multiple data 
      # files *may* share the same properties

      logger.warn "Latitude and Longitude unavailable from metadata."
      logger.warn "These values must be manually added to the station metadata file."

      logger.warn "Time zone offset not available from data source."
      logger.warn "The offset must be manually added to the station metadata file."

      logger.warn "Sensor metadata PDF or SensorML not available from data source."
      logger.warn "The URL may be manually added to the station metadata file under the \"procedure\" key."

      # Convert to Hash
      @metadata = {
        name:            "Campbell Scientific Station #{@id}",
        description:     "Campbell Scientific Weather Station #{@id}",
        latitude:        nil,
        longitude:       nil,
        elevation:       nil,
        timezone_offset: nil,
        updated_at:      Time.now.utc,
        procedure:       nil,
        datastreams:     datastreams,
        data_files:      data_files,
        properties:      @properties
      }

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
      get_metadata

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = @metadata[:datastreams]

      if options[:allowed]
        datastreams = datastreams.filter do |datastream|
          options[:allowed].include?(datastream[:name])
        end
      elsif options[:blocked]
        datastreams = datastreams.filter do |datastream|
          !options[:blocked].include?(datastream[:name])
        end
      end

      # THING entity
      # Create Thing entity
      thing = @entity_factory.new_thing({
        name:        @metadata[:name],
        description: @metadata[:description],
        properties:  {
          provider:              'Campbell Scientific',
          station_id:            @id,
          station_model_name:    @metadata[:properties][:station_model_name],
          station_serial_number: @metadata[:properties][:station_serial_number],
          station_program:       @metadata[:properties][:station_program]
        }
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:"Thing@iot.navigationLink"] = thing.link
      save_metadata

      # LOCATION entity
      # Check if latitude or longitude are blank
      if @metadata[:latitude].nil? || @metadata[:longitude].nil?
        raise "Station latitude or longitude is nil! Location entity cannot be created."
      end
      
      # Create Location entity
      location = @entity_factory.new_location({
        name:         @metadata[:name],
        description:  @metadata[:description],
        encodingType: 'application/vnd.geo+json',
        location: {
          type:        'Point',
          coordinates: [@metadata[:longitude].to_f, @metadata[:latitude].to_f]
        }
      })

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:"Location@iot.navigationLink"] = location.link
      save_metadata

      # SENSOR entities
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = @entity_factory.new_sensor({
          name:        "Campbell Scientific Station #{@id} #{stream[:name]} Sensor",
          description: "Campbell Scientific Station #{@id} #{stream[:name]} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata:     @metadata[:procedure] || "http://example.org/unknown"
        })

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:"Sensor@iot.navigationLink"] = sensor.link
        stream[:"Sensor@iot.id"] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      datastreams.each do |stream|
        # Look up entity in ontology;
        # if nil, then use default attributes
        entity = @ontology.observed_property(stream[:name])

        if entity.nil?
          logger.warn "No Observed Property found in Ontology for CampbellScientific:#{stream[:name]}"
          entity = {
            name:        stream[:name],
            definition:  "http://example.org/#{stream[:name]}",
            description: stream[:name]
          }
        end

        observed_property = @entity_factory.new_observed_property(entity)

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream[:"ObservedProperty@iot.navigationLink"] = observed_property.link
        stream[:"ObservedProperty@iot.id"] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        # Look up UOM, observationType in ontology;
        # if nil, then use default attributes
        uom = @ontology.unit_of_measurement(stream[:name])

        if uom.nil?
          logger.warn "No Unit of Measurement found in Ontology for CampbellScientific:#{stream[:name]} (#{stream[:uom]})"
          uom = {
            name:       stream[:Units] || "",
            symbol:     stream[:Units] || "",
            definition: ''
          }
        end

        observation_type = observation_type_for(stream[:name], @ontology)

        datastream = @entity_factory.new_datastream({
          name:        "Campbell Scientific Station #{@id} #{stream[:name]}",
          description: "Campbell Scientific Station #{@id} #{stream[:name]}",
          unitOfMeasurement: uom,
          observationType: observation_type,
          Sensor: {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty: {
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

    # Save the observations to file cache
    # TODO: Support interval download
    def download_observations(interval = nil)
      get_metadata

      @metadata[:data_files].each do |data_file|
        data_filename = data_file[:filename]
        all_observations = download_observations_for_file(data_file).sort { |a,b| a[0] <=> b[0] }

        # Store Observations in DataStore.
        # Convert to new store format first:
        # * timestamp
        # * result
        # * property
        # * unit
        observations = all_observations.collect do |observation_set|
          timestamp = Time.parse(observation_set[0])
          # observation:
          # * name (property)
          # * reading (result)
          observation_set[1].collect do |observation|
            datastream = @metadata[:datastreams].find do |datastream|
              datastream[:name] == observation[:name]
            end

            if datastream
              {
                timestamp: timestamp,
                result: observation[:reading],
                property: observation[:name],
                unit: datastream[:units]
              }
            else
              nil
            end
          end
        end
        observations.flatten! && observations.compact!
        @data_store.store(observations)

        # Update station metadata cache file with observation date range.
        # Ignore if there are no observations.
        if all_observations[0]
          oldest_in_set         = all_observations[0][0]
          newest_in_set         = all_observations[-1][0]
          data_file[:parsed] ||= {}

          if data_file[:parsed][:oldest].nil? || data_file[:parsed][:oldest] > oldest_in_set
            data_file[:parsed][:oldest] = oldest_in_set
          end

          if data_file[:parsed][:newest].nil? || data_file[:parsed][:newest] < newest_in_set
            data_file[:parsed][:newest] = newest_in_set
          end

          save_metadata
        end
      end
    end

    # Collect all the observation files in the date interval, and upload
    # them.
    # (Kind of wish I had a database here.)
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
      get_metadata

      time_interval = Transloader::TimeInterval.new(interval)
      observations  = @data_store.get_all_in_range(time_interval.start, time_interval.end)

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
      data          = []
      last_modified = nil
      new_length    = nil
      observations  = []

      # Should the full remote file be downloaded, or should a partial
      # download be used instead?
      redownload = true

      # Check if file has already been downloaded, and if so use HTTP
      # Range header to only download the newest part of the file
      if data_file[:last_length]
        # Download part of file; do not use gzip compression
        redownload = false

        # Check if content-length is smaller than expected 
        # (last_length). If it is smaller, that means the file was
        # probably truncated and the file should be re-downloaded 
        # instead.
        response = @http_client.head(uri: data_file[:url])

        last_modified = parse_last_modified(response["Last-Modified"])
        new_length    = response["Content-Length"].to_i

        if response["Content-Length"].to_i < data_file[:last_length]
          logger.info "Remote data file length is shorter than expected."
          redownload = true
        else
          # Do a partial GET
          response = @http_client.get({
            uri: data_file[:url],
            headers: {
              'Accept-Encoding' => '',
              'Range' => "bytes=#{data_file[:last_length]}-"
            }
          })

          # 416 Requested Range Not Satisfiable
          if response.code == "416"
            logger.info "No new data."
          elsif response.code == "206"
            logger.info "Downloaded partial data."
            filedata      = response.body
            last_modified = parse_last_modified(response["Last-Modified"])
            new_length    = data_file[:last_length] + filedata.length
            begin
              data = CSV.parse(filedata)
            rescue CSV::MalformedCSVError => e
              logger.error "Could not parse partial response data.", e
              redownload = true
            end
          else
            # Other codes are probably errors
            logger.error "Error downloading partial data."
          end
        end
      end
        
      if redownload
        logger.info "Downloading entire data file."
        # Download entire file; can use gzip compression
        response = @http_client.get(
          uri: data_file[:url],
          headers: { 'Range' => '' }
        )

        filedata      = response.body
        last_modified = parse_last_modified(response["Last-Modified"])
        new_length    = filedata.length
        data          = CSV.parse(filedata)
        # Parse column headers for observed properties
        # (Skip first column with timestamp)
        column_headers = data[1].slice(1..-1)

        # Store column names in station metadata cache file, as 
        # partial requests later will not be able to know the column
        # headers.
        data_file[:headers] = column_headers
        save_metadata

        # Omit the file header rows from the next step, as the next
        # step may run from a partial file that doesn't know any
        # headers.
        data.slice!(0..3)
      end

      # Update station metadata cache with what the server says is the
      # latest file update time and the latest file length in bytes
      data_file[:last_modified] = to_iso8601(last_modified)
      data_file[:last_length]   = new_length
      save_metadata

      # Parse observations from CSV
      data.each do |row|
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

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download
    # and save to a cache file.
    def get_metadata
      @metadata = @metadata_store.metadata
      if (@metadata == {})
        @metadata = download_metadata
        save_metadata
      end
    end

    # Parse an observation reading from the data source, converting a
    # string to a float or if null (i.e. "NAN") then use STA compatible
    # "null" string.
    # "NAN" usage here is specific to Campbell Scientific loggers.
    def parse_reading(reading)
      reading == "NAN" ? "null" : reading.to_f
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      @metadata_store.merge(@metadata)
    end

    # Upload all observations in an array.
    # * observations: Array of DataStore observations
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will have
    #              observations uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              have observations be uploaded to STA.
    # 
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_observations_array(observations, options = {})
      # Check for metadata
      if @metadata.empty?
        logger.error "station metadata not loaded"
        raise
      end

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = @metadata[:datastreams]

      if options[:allowed]
        datastreams = datastreams.filter do |datastream|
          options[:allowed].include?(datastream[:name])
        end
      elsif options[:blocked]
        datastreams = datastreams.filter do |datastream|
          !options[:blocked].include?(datastream[:name])
        end
      end

      # Create hash map of observed properties to datastream URLs.
      # This is used to determine where Observation entities are 
      # uploaded.
      datastream_hash = datastreams.reduce({}) do |memo, datastream|
        memo[datastream[:name]] = datastream
        memo
      end

      # Observation from DataStore:
      # * timestamp
      # * result
      # * property
      # * unit
      observations.each do |observation|
        datastream = datastream_hash[observation[:property]]

        if datastream.nil?
          logger.warn "No datastream found for observation property: #{observation[:property]}"
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            logger.error "Datastream navigation URLs not cached"
            raise
          end

          phenomenonTime = Time.parse(observation[:timestamp]).iso8601(3)
          result = coerce_result(observation[:result], observation_type_for(datastream[:name], @ontology))

          observation = @entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result: result,
            resultTime: phenomenonTime
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end
    end
  end
end
