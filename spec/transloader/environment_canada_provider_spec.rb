require 'transloader'

require 'rspec'
require 'vcr'

CACHE_DIR = "tmp/cache"

RSpec.describe Transloader::EnvironmentCanadaProvider do

  it "auto-creates a cache directory" do
    provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
    expect(Dir.exist?("#{CACHE_DIR}/environment_canada/metadata")).to be true
  end

  it "creates a station object with the given id" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
      station = provider.get_station(station_id: "CXCM")

      expect(station.id).to eq("CXCM")
      expect(station.metadata).to_not eq({})
    end
  end

  it "initializes a new station without loading any metadata" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
      station = provider.new_station(station_id: "CXCM")
      expect(station.metadata).to eq({})
    end
  end

  it "returns an array of available stations" do
    VCR.use_cassette("environment_canada_stations") do
      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)

      expect(provider.stations).to_not be_empty
    end
  end

  it "raises an error when stations cannot be downloaded" do
    VCR.use_cassette("environment_canada_stations_not_found") do
      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
      expect {
        provider.stations
      }.to raise_error("Error downloading station list")
    end
  end
end
