require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::EnvironmentCanadaProvider do
  before(:each) do
    reset_cache($cache_dir)
    @http_client = Transloader::HTTP.new
  end

  it "initializes a new station without loading any metadata" do
    VCR.use_cassette("environment_canada/stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
      station = provider.get_station(station_id: "CXCM")
      expect(station.metadata).to eq({})
    end
  end

  it "returns an array of available stations" do
    VCR.use_cassette("environment_canada/stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)

      expect(provider.stations).to_not be_empty
    end
  end

  it "raises an error when stations cannot be downloaded" do
    VCR.use_cassette("environment_canada/stations_not_found") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
      expect {
        provider.stations
      }.to raise_error(Transloader::HTTPError, /Error downloading station list/)
    end
  end

  it "does not make an HTTP request if data is already cached" do
    VCR.use_cassette("environment_canada/stations") do
      provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
      provider.stations
      provider.stations
      expect(WebMock).to have_requested(:get, Transloader::EnvironmentCanadaProvider::METADATA_URL).times(1)
    end
  end
end
