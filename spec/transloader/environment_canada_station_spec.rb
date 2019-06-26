require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::EnvironmentCanadaStation do

  # Get Metadata
  context "Downloading Metadata" do
    before(:each) do
      reset_cache($cache_dir)

      # Use instance variables to avoid scope issues with VCR
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("environment_canada/stations") do
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be false

        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
        @station = @provider.get_station(station_id: "CXCM")
        @station.save_metadata

        expect(WebMock).to have_requested(:get, 
          "http://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml").times(1)
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be true
      end
    end

    it "raises an error if metadata source file cannot be downloaded" do
      VCR.use_cassette("environment_canada/observations_not_found") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
        expect {
          @provider.get_station(station_id: "CXCM")
        }.to raise_error("Error downloading station observation data")
      end
    end
  end

  # Put Metadata
  context "Uploading Metadata" do
    # pre-create the station for this context block
    before(:each) do
      reset_cache($cache_dir)
      @provider = nil
      @station = nil

      VCR.use_cassette("environment_canada/stations") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir)
        @station = @provider.get_station(station_id: "CXCM")
        @station.save_metadata
      end

      @sensorthings_url = "http://scratchpad.sensorup.com/OGCSensorThings/v1.0/"
    end

    it "creates a Thing entity and caches the entity URL" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          "#{@sensorthings_url}Things").once
        expect(@station.metadata[:"Thing@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates a Location entity and caches the entity URL" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Locations]).once
        expect(@station.metadata[:"Location@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Sensor entities and caches the URLs" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Sensors]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Sensor@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Observed Property entities and caches the URLs" do
      VCR.use_cassette("environment_canada/metadata_upload") do
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
      pending
      fail
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

  # Get Observations
  context "Downloading Observations" do
    # TODO
  end

  # Put Observations
  context "Uploading Observations" do
    # TODO
  end
end
