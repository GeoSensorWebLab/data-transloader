require 'transloader/data_garrison/station'

module Transloader
  class DataGarrisonProvider
    PROVIDER_NAME = "data_garrison"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(user_id:, station_id:)
      store_opts = {
        cache_path: @cache_path,
        provider: PROVIDER_NAME,
        station: "#{user_id}-#{station_id}"
      }
      data_store     = DataStore.new(store_opts)
      metadata_store = MetadataStore.new(store_opts)

      DataGarrisonStation.new(
        data_store: data_store,
        http_client: @http_client,
        id: station_id,
        metadata_store: metadata_store,
        properties: { user_id: user_id },
        provider: self)
    end
  end
end
