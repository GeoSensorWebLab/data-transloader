require "csv"
require "set"
require "time"

require_relative "../data_file"
require_relative "../station_methods"

module Transloader
  # Class for downloading and uploading metadata and observation data
  # from historical Kluane Lake Research Station (KLRS) data sets. The
  # data is read from local files instead of over HTTP, and the data
  # has the same format as Campbell Scientific weather stations.
  #
  # This class is called by the main Transloader::Station class.
  class KLRSHistoricalWeatherStation
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    LONG_NAME     = "KLRS Historical Weather Station"
    NAME          = "KLRS Weather Station"
    PROVIDER_ID   = "KLRSHistoricalWeather"
    PROVIDER_NAME = "klrs_historical_weather"

    attr_accessor :id, :metadata, :properties

    def initialize(options = {})
      @http_client    = options[:http_client]
      @id             = options[:id]
      @properties     = options[:properties]
      @store          = StationStore.new({
        provider:     PROVIDER_NAME,
        station:      options[:id],
        database_url: options[:database_url]
      })
      @metadata       = {}
      @entity_factory = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Extract metadata from one or more local data files, use to build
    # metadata needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the
    # existing metadata before being cached.
    def download_metadata(override_metadata: {}, overwrite: false)
      if (@store.metadata != {} && !overwrite)
        logger.warn "Existing metadata found, will not overwrite."
        return false
      end

      data_paths  = @properties[:data_paths]
      if data_paths.empty?
        raise Error, "No paths to data files specified. Data files are required to load station metadata."
      end

      data_files  = []
      datastreams = []

      data_paths.each do |path|
        # Open file for reading. If it does not exist, skip it.
        if !File.exists?(path)
          logger.warn "Cannot load data from path: '#{path}'"
          next
        end

        doc = read_toa5_file(path)

        # Store CSV file metadata
        data_files.push(DataFile.new({
          url:           File.absolute_path(path),
          last_modified: to_iso8601(File.mtime(path)),
          length:        File.size(path)
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
        @properties[:station_model_name]    = doc.metadata(:station_name)
        @properties[:station_serial_number] = doc.metadata(:datalogger_serial_number)
        @properties[:station_program]       = doc.metadata(:datalogger_program_name)

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

      # Warn about incomplete metadata
      logger.warn "Sensor metadata PDF or SensorML not available from data source."
      logger.warn "The URL may be manually added to the station metadata file under the \"procedure\" key."

      # Convert to Hash
      @metadata = {
        name:            "#{NAME} #{@id}",
        description:     "#{LONG_NAME} #{@id}",
        latitude:        61.02741,
        longitude:       -138.41071,
        elevation:       nil,
        timezone_offset: "-07:00",
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
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

      # THING entity
      # Create Thing entity
      thing = build_thing({
        provider:              LONG_NAME,
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
      latitude  = @metadata[:latitude]
      longitude = @metadata[:longitude]
      # Check if latitude or longitude are blank
      if latitude.nil? || longitude.nil?
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
        sensor = build_sensor("#{LONG_NAME} #{@id} #{stream[:name]} Sensor")

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

        datastream = @entity_factory.new_datastream({
          name:              "#{LONG_NAME} #{@id} #{datastream_name}",
          description:       "#{LONG_NAME} #{@id} #{datastream_name}",
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

    # Convert the observations from the source data files and serialize
    # into the data store.
    # An interval may be specified to limit the parsing of data.
    def download_observations(interval = nil)
      get_metadata

      @metadata[:data_files].each do |data_file|
        data_filename = data_file[:filename]
        all_observations = load_observations_for_file(data_file)

        # Filter observations by interval, if one is set
        if !interval.nil?
          all_observations = filter_observations(all_observations.sort_by { |obs| obs[0] }, interval)
        end

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
      get_metadata

      time_interval = Transloader::TimeInterval.new(interval)
      observations  = @store.get_data_in_range(time_interval.start, time_interval.end)
      logger.info "Uploading Observations: #{observations.length}"
      upload_observations_array(observations, options)
    end



    # For parsing functionality specific to this data provider
    private

    # Load observations from a local file
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
    def load_observations_for_file(data_file)
      observations   = []
      doc            = read_toa5_file(data_file[:url])
      column_headers = doc.headers.slice(1..-1)

      # Parse observations from CSV
      doc.rows.each do |row|
        # Add seconds to the timestamp, if they are missing.
        time = row[0]
        if time =~ /^\d{4}-\d{2}-\d{2} \d{1,2}:\d{2}$/
          logger.trace "Adding missing seconds to timestamp"
          time += ":00"
        end

        # Transform dates into ISO8601 in UTC.
        # This will make it simpler to group them by day and to simplify
        # timezones for multiple stations.
        timestamp = parse_toa5_timestamp(time, @metadata[:timezone_offset])
        utc_time = to_iso8601(timestamp)
        observations.push([utc_time,
          row[1..-1].map.with_index { |x, index|
            {
              name:    column_headers[index][:name],
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
      @metadata = @store.metadata
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

    # Parse a TOA5 ASCII data file into an array of arrays.
    # Will apply character encoding fix from windows-1252 to utf-8,
    # and automatically detect if file is tab-separated or comma
    # separated.
    def read_toa5_file(path)
      data_document = nil
      separator     = ","

      # Peek first line to determine if it is tabs or commas. The
      # heuristic is whether there are more commas or tabs.
      File.open(path, { encoding: "windows-1252:utf-8" }) do |f|
        first_line = ""
        char       = ""
        # The line endings might be Windows or Unix, so we need to
        # handle both.
        while (char != "\r" && char != "\n") do
          char        = f.getc
          first_line += char
        end

        commas_count = first_line.count(",")
        tabs_count   = first_line.count("\t")
        separator    = tabs_count > commas_count ? "\t" : ","
      end

      begin
        document = IO.read(path, encoding: "windows-1252")
        data_document = Transloader::TOA5Document.new(document, {
          encoding: "windows-1252:utf-8",
          col_sep: separator
        })
      rescue CSV::MalformedCSVError => e
        logger.error "Cannot parse #{path} as CSV file: #{e}"
        exit 1
      end
      data_document
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      @store.merge_metadata(@metadata)
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
        raise Error, "station metadata not loaded"
      end

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

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
      responses = observations.collect do |observation|
        datastream = datastream_hash[observation[:property]]

        if datastream.nil?
          logger.warn "No datastream found for observation property: #{observation[:property]}"
          :unavailable
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            raise Error, "Datastream navigation URLs not cached"
          end

          phenomenonTime = Time.parse(observation[:timestamp]).iso8601(3)
          result = coerce_result(observation[:result], observation_type_for(datastream[:name]))

          observation = @entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result: result,
            resultTime: phenomenonTime
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end

      # output info on how many observations were created and so on
      log_response_types(responses)
    end
  end
end
