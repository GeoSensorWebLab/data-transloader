require 'fileutils'

require 'transloader/data_garrison/station'

module Transloader
  class DataGarrisonProvider
    PROVIDER_NAME = "data_garrison"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client

      FileUtils.mkdir_p("#{@cache_path}/#{PROVIDER_NAME}")
      FileUtils.mkdir_p("#{@cache_path}/#{PROVIDER_NAME}/metadata")
    end

    # Create a new Station object based on the station ID, and
    # automatically load its metadata from data source or file
    def get_station(user_id:, station_id:)
      store_opts = {
        cache_path: @cache_path,
        provider: PROVIDER_NAME,
        station: "#{user_id}-#{station_id}"
      }
      data_store     = DataStore.new(store_opts)
      metadata_store = MetadataStore.new(store_opts)

      stn = DataGarrisonStation.new(
        data_store: data_store,
        http_client: @http_client,
        id: station_id,
        metadata_store: metadata_store,
        properties: { user_id: user_id },
        provider: self)
      stn.get_metadata
      stn
    end

    # Create a new Station object based on the station ID.
    # Does not load any metadata.
    def new_station(user_id:, station_id:)
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
