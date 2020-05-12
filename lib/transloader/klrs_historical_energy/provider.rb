require 'transloader/klrs_historical_energy/station'

module Transloader
  class KLRSHistoricalEnergyProvider
    PROVIDER_ID   = "KLRSHistoricalEnergy"
    PROVIDER_NAME = "klrs_historical_energy"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(station_id:, data_paths: [])
      store_opts = {
        cache_path: @cache_path,
        provider:   PROVIDER_NAME,
        station:    station_id
      }
      data_store     = DataStore.new(store_opts)
      metadata_store = MetadataStore.new(store_opts)

      KLRSHistoricalEnergyStation.new(
        data_store:     data_store,
        http_client:    @http_client,
        id:             station_id,
        metadata_store: metadata_store,
        properties:     { data_paths: data_paths },
        provider:       self
      )
    end
  end
end