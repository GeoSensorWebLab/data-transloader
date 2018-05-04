require 'csv'
require 'fileutils'
require 'json'
require 'net/http'

module Transloader
  class EnvironmentCanada
    CACHE_DIRECTORY = "environment_canada"
    METADATA_URL = "http://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"

    # Download the station list from Environment Canada and return the body string
    def self.download_station_list
      response = Net::HTTP.get_response(URI(METADATA_URL))

      raise "Error downloading station list" if response.code != '200'

      # Data is encoded as ISO-8859-1 but has no encoding headers, so encoding
      # must be manually applied. I then convert to UTF-8 for re-use later.
      body = response.body.force_encoding(Encoding::ISO_8859_1)
      body = body.encode(Encoding::UTF_8)
    end

    # Download list of stations from Environment Canada. If cache file exists,
    # re-use that instead.
    def self.get_stations_list(cache)
      if File.exist?("#{cache}/#{CACHE_DIRECTORY}/stations_list.csv")
        body = IO.read("#{cache}/#{CACHE_DIRECTORY}/stations_list.csv")
      else
        body = self.download_station_list
        self.save_station_list(body, cache)
      end

      CSV.parse(body, headers: :first_row)
    end

    # Cache the raw body data to a file for re-use
    def self.save_station_list(body, cache)
      FileUtils.mkdir_p("#{cache}/#{CACHE_DIRECTORY}")
      IO.write("#{cache}/#{CACHE_DIRECTORY}/stations_list.csv", body, 0)
    end

    # Download the metadata for a station and store in cache file
    def self.get_station_metadata(station, cache)
      stations = self.get_stations_list(cache)

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
      FileUtils.mkdir_p("#{cache}/#{CACHE_DIRECTORY}/metadata")
      IO.write("#{cache}/#{CACHE_DIRECTORY}/metadata/#{station}.json", JSON.pretty_generate(station_details))
    end
  end
end
