require 'csv'
require 'fileutils'
require 'json'
require 'net/http'

module Transloader
  class EnvironmentCanadaProvider
    CACHE_DIRECTORY = "environment_canada"
    METADATA_URL = "http://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"

    def initialize(cache_path)
      @cache_path = cache_path

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      @station_list_path = "#{@cache_path}/#{CACHE_DIRECTORY}/stations_list.csv"
    end

    # Download the station list from Environment Canada and return the body string
    def download_station_list
      response = Net::HTTP.get_response(URI(METADATA_URL))

      raise "Error downloading station list" if response.code != '200'

      # Data is encoded as ISO-8859-1 but has no encoding headers, so encoding
      # must be manually applied. I then convert to UTF-8 for re-use later.
      body = response.body.force_encoding(Encoding::ISO_8859_1)
      body = body.encode(Encoding::UTF_8)
    end

    # Download the metadata for a station and store in cache file
    def get_station_metadata(station)
      stations = get_stations_list

      station_row = stations.detect do |row|
        row["#IATA"] == station
      end

      raise "Station not found in list" if station_row.nil?

      # Convert to Hash
      station_details = {
        name: "Environment Canada Station #{station_row["#IATA"]}",
        description: "Environment Canada Weather Station #{station_row["EN name"]}",
        updated_at: Time.now,
        properties: station_row.to_hash
      }

      # Write to cache file
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
      metadata_path = "#{@cache_path}/#{CACHE_DIRECTORY}/metadata/#{station}.json"
      IO.write(metadata_path, JSON.pretty_generate(station_details))
    end

    # Download list of stations from Environment Canada. If cache file exists,
    # re-use that instead.
    def get_stations_list
      if File.exist?(@station_list_path)
        body = IO.read(@station_list_path)
      else
        body = download_station_list
        save_station_list(body)
      end

      CSV.parse(body, headers: :first_row)
    end

    # Cache the raw body data to a file for re-use
    def save_station_list(body)
      IO.write(@station_list_path, body, 0)
    end
  end
end
