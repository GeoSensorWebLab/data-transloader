module Transloader
  class CampbellScientificStation

    attr_accessor :id, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @user_id = @properties[:user_id]
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{CampbellScientificProvider::CACHE_DIRECTORY}/metadata/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{CampbellScientificProvider::CACHE_DIRECTORY}/#{@id}"
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream
    def download_metadata
      # Convert to Hash
      @metadata = {}
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
      if File.exist?(@metadata_path)
        @metadata = JSON.parse(IO.read(@metadata_path))
      else
        @metadata = download_metadata
        save_metadata
      end
    end

    # Connect to data provider and download Observations
    def get_observations
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
    end

    # Upload station observations for `date` to the SensorThings API 
    # server at `destination`. If `date` is "latest", then the most 
    # recent cached observation file is used.
    def put_observations(destination, date)
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      FileUtils.mkdir_p(File.dirname(@metadata_path))
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end

    # Save the observations to file cache
    def save_observations
    end

    # For parsing functionality specific to this data provider
    private
  end
end
