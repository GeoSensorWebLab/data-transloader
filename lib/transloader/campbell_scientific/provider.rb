require 'fileutils'

require 'transloader/data_store'
require 'transloader/metadata_store'
require 'transloader/campbell_scientific/station'

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. Campbell Scientific stations require URLs
  # to online data files to download.
  class CampbellScientificProvider
    PROVIDER_ID   = "CampbellScientific"
    PROVIDER_NAME = "campbell_scientific"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(station_id:, data_urls: [])
      store = StationStore.new({
        provider:     PROVIDER_NAME,
        station:      station_id,
        database_url: @cache_path
      })
      
      CampbellScientificStation.new(
        http_client: @http_client,
        id:          station_id,
        properties:  { data_urls: data_urls },
        provider:    self,
        store:       store
      )
    end
  end
end
