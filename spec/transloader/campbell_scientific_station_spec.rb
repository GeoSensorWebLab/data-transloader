require 'transloader'

require 'fileutils'
require 'rspec'
require 'time'
require 'vcr'

RSpec.describe Transloader::CampbellScientificStation do

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
      VCR.use_cassette("campbell_scientific/station") do
        metadata_file = "#{$cache_dir}/campbell_scientific/metadata/606830.json"
        expect(File.exist?(metadata_file)).to be false

        @provider = Transloader::CampbellScientificProvider.new($cache_dir)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        @station.save_metadata

        expect(WebMock).to have_requested(:get, 
          "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat").times(1)
        expect(File.exist?(metadata_file)).to be true
      end
    end

    it "raises an error if metadata source file cannot be downloaded" do
      VCR.use_cassette("campbell_scientific/station_not_found") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir)
        expect {
          @provider.get_station(
            station_id: "606830",
            data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/null.dat"]
          )
        }.to raise_error(OpenURI::HTTPError)
      end
    end

    it "overwrites metadata file if it already exists" do
      VCR.use_cassette("campbell_scientific/station") do
        metadata_file = "#{$cache_dir}/campbell_scientific/metadata/606830.json"

        @provider = Transloader::CampbellScientificProvider.new($cache_dir)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
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

  ##############
  # Put Metadata
  ##############
  
  context "Uploading Metadata" do
    # pre-create the station for this context block
    before(:each) do
      reset_cache($cache_dir)
      @provider = nil
      @station = nil

      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        # These values must be fixed before uploading to STA.
        @station.metadata[:latitude] = 68.983639
        @station.metadata[:longitude] = -105.835833
        @station.metadata[:timezone_offset] = "-06:00"
        @station.save_metadata
      end

      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"
    end

    it "creates a Thing entity and caches the entity URL" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          "#{@sensorthings_url}Things").once
        expect(@station.metadata[:"Thing@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates a Location entity and caches the entity URL" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Locations]).once
        expect(@station.metadata[:"Location@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Sensor entities and caches the URLs" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Sensors]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Sensor@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Observed Property entities and caches the URLs" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties]).at_least_once
        expect(@station.metadata[:datastreams][0][:"ObservedProperty@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observed properties to standard observed properties" do
      pending
      fail
    end

    it "creates Datastream entities and caches the URLs" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Datastream@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observation type to O&M observation types on Datastreams" do
      pending
      fail
    end

    it "maps the source observation type to standard UOMs on Datastreams" do
      pending
      fail
    end
  end
end
