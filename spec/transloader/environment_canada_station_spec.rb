require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::EnvironmentCanadaStation do

  ##############
  # Get Metadata
  ##############
  
  context "Downloading Metadata" do
    before(:each) do
      reset_cache($cache_dir)

      # Use instance variables to avoid scope issues with VCR
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("environment_canada/stations") do
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be false

        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(station_id: "CXCM")
        @station.download_metadata

        expect(WebMock).to have_requested(:get, 
          "http://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml").times(1)
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be true
      end
    end

    it "raises an error when the SWOB-ML file cannot be downloaded" do
      VCR.use_cassette("environment_canada/observations_not_found") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(station_id: "CXCM")
        expect {
          @station.download_metadata
        }.to raise_error(Transloader::HTTPError, /SWOB-ML file not found/)
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
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil

      VCR.use_cassette("environment_canada/stations") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(station_id: "CXCM")
        @station.download_metadata
      end

      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"
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
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a label from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties])
          .with(body: /Data Availability/).at_least_once
      end
    end

    it "creates Datastream entities and caches the URLs" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Datastream@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observation type to O&M observation types on Datastreams" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a non-default observation type is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /OM_Measurement/).at_least_once
      end
    end

    it "maps the source observation type to standard UOMs on Datastreams" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a definition from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /UO_0000187/).at_least_once
      end
    end

    it "filters entities uploaded according to an allow list" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, allowed: ["data_avail"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .times(1)
      end
    end

    it "filters entities uploaded according to a block list" do
      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, blocked: ["data_avail"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .times(52)
      end
    end
  end

  ##################
  # Get Observations
  ##################
  
  context "Downloading Observations" do
    # pre-create the station for this context block
    before(:each) do
      reset_cache($cache_dir)
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil
      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"

      VCR.use_cassette("environment_canada/stations") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(station_id: "CXCM")
        @station.download_metadata
      end

      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end
    end

    it "downloads the latest data by default" do
      VCR.use_cassette("environment_canada/stations") do
        expect(WebMock).to have_requested(:get, 
          "http://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml")
          .times(1)

        @station.download_observations

        expect(WebMock).to have_requested(:get, 
          "http://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml")
          .times(2)
      end
    end

    # TODO: Download historical to data store
    # TODO: Returns an error if no historical data is available to download
  end

  ##################
  # Put Observations
  ##################
  
  context "Uploading Observations" do
    # pre-create the station for this context block
    before(:each) do
      reset_cache($cache_dir)
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil
      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"

      VCR.use_cassette("environment_canada/stations") do
        @provider = Transloader::EnvironmentCanadaProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(station_id: "CXCM")
        @station.download_metadata
      end

      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end

      VCR.use_cassette("environment_canada/stations") do
        @station.download_observations
      end
    end

    it "uploads observations for a time range" do
      VCR.use_cassette("environment_canada/observations_upload_interval") do
        @station.upload_observations(@sensorthings_url, "2019-06-25T19:00:00Z/2019-06-25T21:00:00Z")

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).at_least_once
      end
    end

    it "filters entities uploaded in an interval according to an allow list" do
      VCR.use_cassette("environment_canada/observations_upload_interval_allowed") do
        @station.upload_observations(@sensorthings_url, "2019-06-25T19:00:00Z/2019-06-25T21:00:00Z", 
          allowed: ["min_batry_volt_pst1hr"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(1)
      end
    end

    it "filters entities uploaded in an interval according to a block list" do
      VCR.use_cassette("environment_canada/observations_upload_interval_blocked") do
        @station.upload_observations(@sensorthings_url, "2019-06-25T19:00:00Z/2019-06-25T21:00:00Z",
          blocked: ["min_batry_volt_pst1hr"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(52)
      end
    end
  end
end
