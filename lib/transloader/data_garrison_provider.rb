require 'fileutils'

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

    # Create a new Station object based on the station ID, and
    # automatically load its metadata from data source or file
    def get_station(user_id:, station_id:)
      stn = DataGarrisonStation.new(station_id, self, { user_id: user_id })
      stn.get_metadata
      stn
    end

    # Create a new Station object based on the station ID.
    # Does not load any metadata.
    def new_station(user_id:, station_id:)
      DataGarrisonStation.new(station_id, self, { user_id: user_id })
    end
  end
end
