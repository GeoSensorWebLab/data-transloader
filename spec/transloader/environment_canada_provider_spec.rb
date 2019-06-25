require 'transloader'

require 'rspec'

CACHE_DIR = "tmp/cache"

RSpec.describe Transloader::EnvironmentCanadaProvider do
  it "auto-creates a cache directory" do
    provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
    expect(Dir.exist?("#{CACHE_DIR}/environment_canada/metadata")).to be true
  end

  it "creates a station object with the given id" do
    provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
    station = provider.get_station(station_id: "CXCM")
    expect(station.id).to eq("CXCM")
    expect(station.metadata).to_not eq({})
  end

  it "initializes a new station without loading any metadata" do
    provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
    station = provider.new_station(station_id: "CXCM")
    expect(station.metadata).to eq({})
  end

  it "returns an array of available stations" do
    provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
    expect(provider.stations).to_not be_empty
  end
end
