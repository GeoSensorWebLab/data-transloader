require "transloader/klrs_historical_weather/station"

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. KLRS Historical Weather data stations
  # require local data file paths.
  class KLRSHistoricalWeatherProvider
    PROVIDER_ID   = "KLRSHistoricalWeather"
    PROVIDER_NAME = "klrs_historical_weather"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client
    end

    # Create a new Station object based on the station ID
    def get_station(station_id:, data_paths: [])
      KLRSHistoricalWeatherStation.new(
        database_url: @cache_path,
        http_client:  @http_client,
        id:           station_id,
        properties:   { data_paths: data_paths },
        provider:     self
      )
    end
  end
end
