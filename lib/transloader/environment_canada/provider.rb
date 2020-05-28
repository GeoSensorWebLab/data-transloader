require 'csv'
require 'fileutils'

require 'transloader/data_store'
require 'transloader/metadata_store'
require 'transloader/environment_canada/station'

module Transloader
  # Provider is used for initializing stations with the correct
  # provider-specific logic. Environment Canada stations requires extra
  # logic here to download the official list of stations and retrieve
  # additional station metadata (e.g. latitude/longitude).
  class EnvironmentCanadaProvider
    include SemanticLogger::Loggable

    PROVIDER_ID   = "EnvironmentCanada"
    PROVIDER_NAME = "environment_canada"
    METADATA_URL = "https://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path  = cache_path
      @http_client = http_client

      FileUtils.mkdir_p("#{@cache_path}/#{PROVIDER_NAME}")
      @station_list_path = "#{@cache_path}/#{PROVIDER_NAME}/stations_list.csv"
    end

    # Create a new Station object based on the station ID.
    # Does not load any metadata.
    def get_station(station_id:)
      station_row = get_station_row(station_id)
      EnvironmentCanadaStation.new(
        database_url: @cache_path,
        http_client:  @http_client,
        id:           station_id,
        properties:   station_row.to_hash,
        provider:     self
      )
    end

    def stations
      @stations ||= get_stations_list
    end

    private

    # Download the station list from Environment Canada and return the 
    # body string
    def download_station_list
      response = @http_client.get(uri: METADATA_URL)

      if response.code != "200"
        raise HTTPError.new(response, "Error downloading station list from Environment Canada")
      end

      # Data is encoded as ISO-8859-1 but has no encoding headers, so 
      # encoding must be manually applied. I then convert to UTF-8 for 
      # re-use later.
      body = response.body.force_encoding(Encoding::ISO_8859_1)
      body = body.encode(Encoding::UTF_8)
    end

    # Download list of stations from Environment Canada. If cache file 
    # exists, re-use that instead.
    def get_stations_list
      if File.exist?(@station_list_path)
        body = IO.read(@station_list_path)
      else
        body = download_station_list
        save_station_list(body)
      end

      parsed_stations = CSV.parse(body, headers: :first_row)
      validate_stations(parsed_stations)
      parsed_stations
    end

    def get_station_row(station_id)
      station_row = stations.detect { |row| row["IATA_ID"] == station_id }
      if station_row.nil?
        raise Error, "Station \"#{station_id}\" not found in list"
      end
      station_row
    end

    # Cache the raw body data to a file for re-use
    def save_station_list(body)
      IO.write(@station_list_path, body, 0)
    end

    # Validate the format of the stations.
    # If they have changed, then the code will probably fail to update
    # and a warning should be emitted.
    def validate_stations(stations)
      if stations.headers.join(",") != "IATA_ID,Name,WMO_ID,MSC_ID,Latitude,Longitude,Elevation(m),Data_Provider,Dataset/Network,AUTO/MAN,Province/Territory"
        logger.warn "Environment Canada stations source file headers have changed. Parsing may fail."
      end
    end
  end
end
