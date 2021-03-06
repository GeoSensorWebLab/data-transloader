require "spreadsheet"
require "time"

require_relative "../data_file"
require_relative "../station"
require_relative "../station_methods"

module Transloader
  # Class for downloading and uploading metadata and observation data
  # from historical Kluane Lake Research Station (KLRS) energy
  # monitoring data sets. The data is read from local files instead of
  # over HTTP, and the data has a custom format in Excel spreadsheet
  # files.
  class KLRSHistoricalEnergyStation < Station
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    LONG_NAME     = "KLRS Historical Energy Usage"
    NAME          = "KLRS Energy Usage"
    PROVIDER_ID   = "KLRSHistoricalEnergy"
    PROVIDER_NAME = "klrs_historical_energy"

    attr_reader :id, :metadata, :properties

    def initialize(options = {})
      @http_client = options[:http_client]
      @id          = options[:id]
      @store       = StationStore.new({
        provider:     PROVIDER_NAME,
        station:      @id,
        database_url: options[:database_url]
      })

      @metadata = @store.metadata
      # TODO: These checks can be removed when the arguments are
      # changed to keywords
      @metadata[:properties] ||= {}
      properties = options[:properties] || {}
      @metadata[:properties].merge!(properties)
    end

    # Extract metadata from one or more local data files, use to build
    # metadata needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the
    # existing metadata before being cached.
    def download_metadata(override_metadata: {})
      properties = @metadata[:properties]

      data_paths  = properties[:data_paths]
      if data_paths.empty?
        raise Error, "No paths to data files specified. Data files are required to load station metadata."
      end

      data_files  = []
      datastreams = []

      data_paths.each do |path|
        logger.info "Attempting to parse '#{path}'"
        # Open file for reading. If it does not exist, skip it.
        if !File.exists?(path)
          logger.warn "Cannot load data from path: '#{path}'"
          next
        end

        # Store Excel file metadata
        data_files.push(DataFile.new({
          url:           File.absolute_path(path),
          last_modified: to_iso8601(File.mtime(path)),
          length:        File.size(path)
        }).to_h)

        Spreadsheet.client_encoding = "UTF-8"
        book = Spreadsheet.open(path)

        # Parse "Configuration". The following metadata is extracted for
        # the properties on the `Thing` entity. Note that parsing
        # multiple data files will cause this data to be overwritten
        # with the contents of the last parsed data file.
        raw_config = book.worksheet("Configuration")
        properties[:configuration] = {
          "Session Name"                  => raw_config.row(3)[1],
          "Electrical hook-up"            => raw_config.row(12)[1],
          "Nominal frequency mode"        => raw_config.row(13)[1],
          "Serial number"                 => raw_config.row(16)[1],
          "PEL name"                      => raw_config.row(17)[1],
          "PEL location"                  => raw_config.row(18)[1],
          "DSP firmware version"          => raw_config.row(20)[1],
          "Hardware version"              => raw_config.row(21)[1],
          "Current sensor 1"              => raw_config.row(25)[1],
          "Current sensor 2"              => raw_config.row(26)[1],
          "Primary nominal current"       => raw_config.row(27)[1],
          "Secondary nominal current"     => raw_config.row(28)[1],
          "Nominal current (BNC Adapter)" => raw_config.row(36)[1],
          "Output voltage (BNC Adapter)"  => raw_config.row(37)[1]
        }

        # Add datastreams for "Event Log". Parsing is not necessary as
        # we do not get any data at this point.
        datastreams.push({
          name:  "event log",
          units: "",
          type:  "value"
        })
        datastreams.push({
          name:  "event codes",
          units: "",
          type:  "value"
        })

        # Parse "Summary" sheet headers for datastreams and units
        raw_summary = book.worksheet("Summary")

        # Only the first two rows are needed. Here we merge the rows
        # together to form pairs for the datastream name and the unit of
        # measurement.
        headers = raw_summary.rows[0].zip(raw_summary.rows[1])

        # We skip the first two date and time columns
        headers.slice!(0, 2)

        headers.each do |name, unit|
          datastreams.push({
            name:  name,
            units: unit,
            type:  nil
          })
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
      @metadata.merge!({
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
        provider:   LONG_NAME,
        station_id: @id
      }.merge(@metadata[:properties][:configuration]))

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

        datastream = entity_factory.new_datastream({
          name:              "#{LONG_NAME} #{@id} #{datastream_name}",
          description:       "#{LONG_NAME} #{@id} #{datastream_name}",
          unitOfMeasurement: uom_for_datastream(datastream_name, stream[:Units]),
          observationType:   observation_type_for(datastream_name),
          Sensor:            {
            "@iot.id" => stream[:"Sensor@iot.id"]
          },
          ObservedProperty:  {
            "@iot.id" => stream[:"ObservedProperty@iot.id"]
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
      logger.info "Parsing observations from #{data_file[:url]}"
      observations = []

      # Open file
      Spreadsheet.client_encoding = "UTF-8"
      book = Spreadsheet.open(data_file[:url])

      # Parse "Summary" worksheet
      raw_summary = book.worksheet("Summary")

      # Grab the headers so we can map the readings to a datastream
      column_headers = raw_summary.rows[0]

      # Omit the file header rows from the next step
      rows = raw_summary.rows[2..-1]

      # Parse observations from rows
      rows.each do |row|
        # Transform dates into ISO8601 in UTC.
        # Sample date: "4/27/2014"
        # Sample time: "7:48:00 PM"
        date      = row[0]
        time      = row[1]
        timestamp = Time.strptime("#{date} #{time} #{@metadata[:timezone_offset]}",
          "%m/%e/%Y %I:%M:%S %p %z")
        utc_time  = to_iso8601(timestamp)

        # Note that "row" must be converted to an array for the range to
        # work correctly.
        observations.push([utc_time,
          row.to_a[2..-1].map.with_index { |x, i|
            {
              name:    column_headers[i],
              reading: parse_reading(x)
            }
          }
        ])
      end

      observations
    end

    # Parse an observation reading from the data source, and use STA
    # compatible "null" string for "missing" values.
    # This function *does not* try to convert to Floats as some values
    # may be strings.
    # "- - -" usage here is specific to these loggers.
    def parse_reading(reading)
      reading == "- - -" ? "null" : reading
    end
  end
end
