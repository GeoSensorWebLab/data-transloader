require_relative "station"

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. KLRS Historical Energy data stations
  # require local data file paths.
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
      KLRSHistoricalEnergyStation.new(
        database_url: @cache_path,
        http_client:  @http_client,
        id:           station_id,
        properties:   { data_paths: data_paths },
        provider:     self
      )
    end
  end
end
