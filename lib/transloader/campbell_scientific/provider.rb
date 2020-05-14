require 'fileutils'

require 'transloader/data_store'
require 'transloader/metadata_store'
require 'transloader/campbell_scientific/station'

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. Campbell Scientific stations require URLs
  # to online data files to download.
  class CampbellScientificProvider
    PROVIDER_NAME = "campbell_scientific"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(station_id:, data_urls: [])
      store_opts = {
        cache_path: @cache_path,
        provider: PROVIDER_NAME,
        station: station_id
      }
      data_store     = DataStore.new(store_opts)
      metadata_store = MetadataStore.new(store_opts)
      
      CampbellScientificStation.new(
        data_store: data_store,
        http_client: @http_client,
        id: station_id,
        metadata_store: metadata_store,
        properties: { data_urls: data_urls },
        provider: self)
    end
  end
end
