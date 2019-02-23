require 'csv'
require 'fileutils'
require 'net/http'
require 'uri'

require 'transloader/data_garrison_station'

module Transloader
  class DataGarrisonProvider
    CACHE_DIRECTORY = "data_garrison"

    attr_accessor :cache_path

    def initialize(cache_path)
      @cache_path = cache_path

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
    end

    # With a User ID and a Station ID, create a new station object
    def get_station(user_id, station_id)
      DataGarrisonStation.new(station_id, self, {
        user_id: user_id
      })
    end
  end
end
