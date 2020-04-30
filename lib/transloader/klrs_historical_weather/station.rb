require 'csv'
require 'time'
require 'transloader/data_file'
require 'transloader/station_methods'

module Transloader
  class KLRSHistoricalWeatherStation
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    attr_accessor :data_store, :id, :metadata, :properties, :provider

    def initialize(options = {})
      @data_store        = options[:data_store]
      @http_client       = options[:http_client]
      @id                = options[:id]
      @metadata_store    = options[:metadata_store]
      @provider          = options[:provider]
      @properties        = options[:properties]
      @metadata          = {}
      @ontology          = KLRSHistoricalWeatherOntology.new
      @entity_factory    = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Extract metadata from one or more local data files, use to build
    # metadata needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the 
    # existing metadata before being cached.
    def download_metadata(override_metadata: {}, overwrite: false)
      if (@metadata_store.metadata != {} && !overwrite)
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

        # Important: Encoding must be set before opening the file. Here
        # we convert to UTF-8 as that is what our database will expect.
        data = CSV.read(path, { encoding: "windows-1252:utf-8" })

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
        data[1].slice(1..-1).each_with_index do |col, index|
          datastreams.push({
            name: col,
            units: data[2][1+index],
            type: data[3][1+index]
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
      @metadata = {
        name:            "KLRS Weather Station #{@id}",
        description:     "KLRS Historical Weather Station #{@id}",
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
      # TODO
      raise "Unimplemented Method"
    end

    # Convert the observations from the source data files and serialize
    # into the data store.
    # An interval may be specified to limit the parsing of data.
    def download_observations(interval = nil)
      # TODO
      raise "Unimplemented Method"
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
      # TODO
      raise "Unimplemented Method"
    end



    # For parsing functionality specific to this data provider
    private

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
  end
end
