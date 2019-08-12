require 'csv'
require 'fileutils'

require 'transloader/metadata_store'
require 'transloader/environment_canada/station'

module Transloader
  class EnvironmentCanadaProvider
    include SemanticLogger::Loggable

    CACHE_DIRECTORY = "environment_canada"
    METADATA_URL = "http://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"

    attr_accessor :cache_path

    def initialize(cache_path, http_client)
      @cache_path = cache_path
      @http_client = http_client

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
      @station_list_path = "#{@cache_path}/#{CACHE_DIRECTORY}/stations_list.csv"
    end

    # Create a new Station object based on the station ID, and
    # automatically load its metadata from data source or file
    def get_station(station_id:)
      station_row = get_station_row(station_id)
      metadata_store = MetadataStore.new({
        cache_path: @cache_path,
        provider: "environment_canada",
        station: station_id
      })
      stn = EnvironmentCanadaStation.new(
        id: station_id,
        metadata_store: metadata_store,
        provider: self,
        http_client: @http_client,
        properties: station_row.to_hash)
      stn.get_metadata
      stn
    end

    # Create a new Station object based on the station ID.
    # Does not load any metadata.
    def new_station(station_id:)
      station_row = get_station_row(station_id)
      metadata_store = MetadataStore.new({
        cache_path: @cache_path,
        provider: "environment_canada",
        station: station_id
      })
      EnvironmentCanadaStation.new(
        id: station_id,
        metadata_store: metadata_store,
        provider: self,
        http_client: @http_client,
        properties: station_row.to_hash)
    end

    def stations
      @stations ||= get_stations_list
    end

    private

    # Download the station list from Environment Canada and return the 
    # body string
    def download_station_list
      response = @http_client.get(uri: METADATA_URL)

      raise "Error downloading station list" if response.code != '200'

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
        logger.error "Station \"#{station_id}\" not found in list"
        raise
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
