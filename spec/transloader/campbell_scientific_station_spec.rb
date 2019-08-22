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
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("campbell_scientific/station") do
        metadata_file = "#{$cache_dir}/v2/campbell_scientific/metadata/606830.json"
        expect(File.exist?(metadata_file)).to be false

        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        @station.download_metadata

        expect(WebMock).to have_requested(:get, 
          "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat").times(1)
        expect(File.exist?(metadata_file)).to be true
      end
    end

    it "stores the data file's HTTP response headers in the metadata" do
      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        expect(@station.metadata[:data_files]).to eq(nil)

        @station.download_metadata

        # These may need to be updated if the VCR recording is updated
        expect(@station.metadata[:data_files][0][:last_modified]).to eq("2019-07-02T20:06:09.000Z")
        expect(@station.metadata[:data_files][0][:initial_length]).to eq(205208)
        expect(@station.metadata[:data_files][0][:last_length]).to eq(nil)
      end
    end

    it "parses the datastreams from the data file headers" do
      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        expect(@station.metadata[:datastreams]).to eq(nil)

        @station.download_metadata

        expect(@station.metadata[:datastreams].length).to eq(22)
      end
    end

    # TODO: Removes duplicate datastreams parsed from the headers of 
    # multiple data files
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

      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        # These values must be fixed before uploading to STA.
        @station.download_metadata(override_metadata: {
          latitude: 68.983639,
          longitude: -105.835833,
          timezone_offset: "-06:00"
        }, overwrite: true)
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
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a label from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties])
          .with(body: /Air Temperature/).at_least_once
      end
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
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a non-default observation type is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /OM_Measurement/).at_least_once
      end
    end

    it "maps the source observation type to standard UOMs on Datastreams" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a definition from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /UO_0000027/).at_least_once
      end
    end

    it "filters entities uploaded according to an allow list" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, allowed: ["BP_Avg"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .once
      end
    end

    it "filters entities uploaded according to a block list" do
      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, blocked: ["BP_Avg"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .times(21)
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

      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        # These values must be fixed before uploading to STA.
        @station.download_metadata(override_metadata: {
          latitude: 68.983639,
          longitude: -105.835833,
          timezone_offset: "-06:00"
        }, overwrite: true)
      end

      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end
    end
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

      VCR.use_cassette("campbell_scientific/station") do
        @provider = Transloader::CampbellScientificProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          station_id: "606830",
          data_urls: ["http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat"]
        )
        # These values must be fixed before uploading to STA.
        @station.download_metadata(override_metadata: {
          latitude: 68.983639,
          longitude: -105.835833,
          timezone_offset: "-06:00"
        }, overwrite: true)
      end

      VCR.use_cassette("campbell_scientific/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end

      VCR.use_cassette("campbell_scientific/observations_download") do
        @station.download_observations
      end
    end

    it "filters entities uploaded in an interval according to an allow list" do
      VCR.use_cassette("campbell_scientific/observation_upload_interval_allowed") do
        @station.upload_observations(@sensorthings_url, "2019-06-28T14:00:00Z/2019-06-28T15:00:00Z", allowed: ["BP_Avg"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(2)
      end
    end

    it "filters entities uploaded in an interval according to a block list" do
      VCR.use_cassette("campbell_scientific/observation_upload_interval_blocked") do
        @station.upload_observations(@sensorthings_url, "2019-06-28T16:00:00Z/2019-06-28T17:00:00Z", blocked: ["BP_Avg"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(42)
      end
    end
  end
end
