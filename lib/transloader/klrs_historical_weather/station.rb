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
      # TODO
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
    end

    # Convert the observations from the source data files and serialize
    # into the data store.
    # An interval may be specified to limit the parsing of data.
    def download_observations(interval = nil)
      # TODO
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
