require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::CampbellScientificProvider do
  before(:each) do
    reset_cache($cache_dir)
    @database_url = "file://#{$cache_dir}"
    @http_client = Transloader::HTTP.new
  end

  it "initializes a new station without loading any metadata" do
    VCR.use_cassette("campbell_scientific/station") do
      provider = Transloader::CampbellScientificProvider.new(@database_url, @http_client)
      station = provider.get_station(
        station_id: "606830",
        data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
      )
      expect(station.id).to eq("606830")
      expect(station.properties[:data_urls]).to include("http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat")
      expect(station.metadata).to eq({})
    end
  end
end
