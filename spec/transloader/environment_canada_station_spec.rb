require 'transloader'

require 'rspec'
require 'vcr'

CACHE_DIR = "tmp/cache"

RSpec.describe Transloader::EnvironmentCanadaStation do

  before(:each) do
    FileUtils.rm_rf("tmp")
    FileUtils.mkdir_p("tmp/cache")
  end

  it "saving the metadata will download the station metadata" do
    VCR.use_cassette("environment_canada_stations") do
      expect(File.exist?("#{CACHE_DIR}/environment_canada/metadata/CXCM.json")).to be false

      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
      station = provider.get_station(station_id: "CXCM")
      station.save_metadata

      expect(WebMock).to have_requested(:get, 
        "http://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml").times(1)
      expect(File.exist?("#{CACHE_DIR}/environment_canada/metadata/CXCM.json")).to be true
    end
  end

  it "raises an error if metadata source file cannot be downloaded" do
    VCR.use_cassette("environment_canada_observations_not_found") do
      provider = Transloader::EnvironmentCanadaProvider.new(CACHE_DIR)
      expect {
        station = provider.get_station(station_id: "CXCM")
      }.to raise_error("Error downloading station observation data")
    end
  end
end
