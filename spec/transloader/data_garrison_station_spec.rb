require 'transloader'

require 'fileutils'
require 'rspec'
require 'time'
require 'vcr'

RSpec.describe Transloader::DataGarrisonStation do

  ##############
  # Get Metadata
  ##############
  
  context "Downloading Metadata" do
    before(:each) do
      reset_cache($cache_dir)

      # Use instance variables to avoid scope issues with VCR
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/data_garrison/metadata/300234063581640/300234065673960.json"
        expect(File.exist?(metadata_file)).to be false

        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.save_metadata

        expect(WebMock).to have_requested(:get, 
          %r[https://datagarrison\.com/users/300234063581640/300234065673960/index\.php.+]).times(1)
        expect(File.exist?(metadata_file)).to be true
      end
    end

    it "raises an error if metadata source file cannot be downloaded" do
      VCR.use_cassette("data_garrison/station_not_found") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        expect {
          @provider.get_station(
            user_id: "300234063581640",
            station_id: "300234065673960"
          )
        }.to raise_error(OpenURI::HTTPError)
      end
    end

    it "overwrites metadata file if it already exists" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/data_garrison/metadata/300234063581640/300234065673960.json"

        @provider = Transloader::DataGarrisonProvider.new($cache_dir)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.save_metadata
        # drop the modified time back 1 day, so we can check to see if
        # it is actually updated
        File.utime((Time.now - 86400), (Time.now - 86400), metadata_file)
        mtime = File.stat(metadata_file).mtime

        @station.save_metadata

        expect(File.stat(metadata_file).mtime).to_not eq(mtime)
      end
    end
  end
end
