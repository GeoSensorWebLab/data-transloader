require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::DataGarrisonProvider do
  before(:each) do
    reset_cache($cache_dir)
    @http_client = Transloader::HTTP.new
  end

  it "creates a station object with the given user id and station id" do
    VCR.use_cassette("data_garrison/station") do
      provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
      station = provider.get_station(
        user_id: "300234063581640",
        station_id: "300234065673960"
      )

      expect(station.id).to eq("300234065673960")
      expect(station.properties[:user_id]).to eq("300234063581640")
      expect(station.metadata).to_not eq({})
    end
  end

  it "initializes a new station without loading any metadata" do
    VCR.use_cassette("data_garrison/station") do
      provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
      station = provider.new_station(
        user_id: "300234063581640",
        station_id: "300234065673960"
      )
      expect(station.metadata).to eq({})
    end
  end
end
