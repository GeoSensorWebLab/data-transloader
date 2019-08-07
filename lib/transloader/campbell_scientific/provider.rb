require 'fileutils'

require 'transloader/campbell_scientific/station'

module Transloader
  class CampbellScientificProvider
    CACHE_DIRECTORY = "campbell_scientific"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
    end

    # Create a new Station object based on the station ID, and
    # automatically load its metadata from data source or file
    def get_station(station_id:, data_urls: [])
      stn = CampbellScientificStation.new(
        id: station_id,
        provider: self,
        http_client: @http_client,
        properties: { data_urls: data_urls })
      stn.get_metadata
      stn
    end

    # Create a new Station object based on the station ID.
    # Does not load any metadata.
    def new_station(station_id:, data_urls: [])
      CampbellScientificStation.new(
        id: station_id,
        provider: self,
        http_client: @http_client,
        properties: { data_urls: data_urls })
    end
  end
end
