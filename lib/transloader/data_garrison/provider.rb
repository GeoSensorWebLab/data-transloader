require "transloader/data_garrison/station"

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. Data Garrison stations require user ids in
  # addition to station ids.
  class DataGarrisonProvider
    PROVIDER_ID   = "DataGarrison"
    PROVIDER_NAME = "data_garrison"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(user_id:, station_id:)
      DataGarrisonStation.new(
        database_url: @cache_path,
        http_client:  @http_client,
        id:           station_id,
        properties:   { user_id: user_id },
        provider:     self
      )
    end
  end
end
