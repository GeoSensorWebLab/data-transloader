module Transloader
  # Station class that acts as a façade to the provider-specific 
  # stations. By using this single interface, clients do not have to
  # know the provider-specific ETL methods. This also means any 
  # provider-specific station class must implement the same 
  # download/upload public methods, at a minimum.
  class Station
    include SemanticLogger::Loggable

    # Options:
    # * cache: String, path to data/metadata store
    # * data_urls: Array (Campbell Scientific only)
    # * http_client: Transloader::HTTP instance
    # * provider: String
    # * station_id: String
    # * user_id: String (Data Garrison only)
    def initialize(options = {})
      @http_client = options[:http_client]
      @provider = provider_class(options[:provider])
        .new(options[:cache], options[:http_client])
      @station = get_station(@provider, options)
    end

    # Download the station metadata to the metadata store cache.
    # `override_attributes`: Hash of attributes to merge into the 
    # metadata before it is sent to the MetadataStore.
    def download_metadata(override_attributes = nil)
      @station.download_metadata(override_attributes)
    end

    # Upload the station metadata from the MetadataStore cache to 
    # SensorThings API
    def upload_metadata(server_url, options = {})
      @station.upload_metadata(server_url, options)
    end

    # Download the station observations for an interval to the DataStore 
    # cache
    def download_observations(interval = nil)
      @station.download_observations(interval)
    end

    # Upload the station observations in `interval` from the DataStore
    # cache to SensorThings API. `destination` may be ignored and the
    # cached URLs (from metadata store cache) will be used instead.
    def upload_observations(destination, interval, options = {})
      @station.upload_observations(destination, interval, options)
    end

    private

    # Create the provider-specific station object
    def get_station(provider, options)
      case provider.class.to_s
      when "Transloader::EnvironmentCanadaProvider"
        provider.get_station(
          station_id: options[:station_id]
        )
      when "Transloader::DataGarrisonProvider"
        provider.get_station(
          station_id: options[:station_id],
          user_id: options[:user_id]
        )
      when "Transloader::CampbellScientificProvider"
        provider.get_station(
          data_urls: options[:data_urls],
          station_id: options[:station_id]
        )
      else
        raise "Unhandled provider class: #{provider.class}"
      end
    end

    # Select the correct Provider class from the name parameter
    def provider_class(provider_name)
      case provider_name
      when "environment_canada" then EnvironmentCanadaProvider
      when "data_garrison" then DataGarrisonProvider
      when "campbell_scientific" then CampbellScientificProvider
      else raise "Unknown provider name: #{provider_name}"
      end
    end
  end
end
