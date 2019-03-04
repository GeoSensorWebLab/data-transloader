require 'fileutils'

require 'transloader/campbell_scientific_station'

module Transloader
  class CampbellScientificProvider
    CACHE_DIRECTORY = "campbell_scientific"

    attr_accessor :cache_path

    def initialize(cache_path)
      @cache_path = cache_path

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
    end

    # With a Station ID, create a new station object
    def get_station(station_id, data_urls)
      CampbellScientificStation.new(station_id, self, {
        data_urls: data_urls
      })
    end
  end
end
