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
      @http_client = Transloader::HTTP.new
      @provider = nil
      @station = nil
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/v2/data_garrison/metadata/300234063581640-300234065673960.json"
        expect(File.exist?(metadata_file)).to be false

        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
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
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        expect {
          @provider.get_station(
            user_id: "300234063581640",
            station_id: "300234065673960"
          )
        }.to raise_error(RuntimeError, "Could not download station data")
      end
    end

    it "overwrites metadata file if it already exists" do
      VCR.use_cassette("data_garrison/station") do
        metadata_file = "#{$cache_dir}/v2/data_garrison/metadata/300234063581640-300234065673960.json"

        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
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

      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        # These values must be fixed before uploading to STA.
        @station.metadata[:latitude] = 69.158
        @station.metadata[:longitude] = -107.0403
        @station.metadata[:timezone_offset] = "-06:00"
        # Fix for error in source data
        @station.metadata[:datastreams].last[:id] = "Backup Batteries"
        @station.save_metadata
      end

      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"
    end

    it "creates a Thing entity and caches the entity URL" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          "#{@sensorthings_url}Things").once
        expect(@station.metadata[:"Thing@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates a Location entity and caches the entity URL" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Locations]).once
        expect(@station.metadata[:"Location@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Sensor entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Sensors]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Sensor@iot.navigationLink"]).to_not be_empty
      end
    end

    it "creates Observed Property entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties]).at_least_once
        expect(@station.metadata[:datastreams][0][:"ObservedProperty@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observed properties to standard observed properties" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a label from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}ObservedProperties])
          .with(body: /Battery Voltage/).at_least_once
      end
    end

    it "creates Datastream entities and caches the URLs" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams]).at_least_once
        expect(@station.metadata[:datastreams][0][:"Datastream@iot.navigationLink"]).to_not be_empty
      end
    end

    it "maps the source observation type to O&M observation types on Datastreams" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a non-default observation type is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /OM_Measurement/).at_least_once
      end
    end

    it "maps the source observation type to standard UOMs on Datastreams" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)

        # Check that a definition from the ontology is used
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .with(body: /UO_0000218/).at_least_once
      end
    end

    it "filters entities uploaded according to an allow list" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, allowed: ["Pressure"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .once
      end
    end

    it "filters entities uploaded according to a block list" do
      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url, blocked: ["Pressure"])

        # Only a single Datastream should be created
        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Things\(\d+\)/Datastreams])
          .times(6)
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

      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        # These values must be fixed before uploading to STA.
        @station.metadata[:latitude] = 69.158
        @station.metadata[:longitude] = -107.0403
        @station.metadata[:timezone_offset] = "-06:00"
        # Fix for error in source data
        @station.metadata[:datastreams].last[:id] = "Backup Batteries"
        @station.save_metadata
      end

      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end
    end

    it "creates a dated directory for the observations data cache" do
      @station.save_observations
      expect(File.exist?("#{$cache_dir}/data_garrison/300234063581640/300234065673960/2019/06/26/144300Z.html")).to be true
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

      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        # These values must be fixed before uploading to STA.
        @station.metadata[:latitude] = 69.158
        @station.metadata[:longitude] = -107.0403
        @station.metadata[:timezone_offset] = "-06:00"
        # Fix for error in source data
        @station.metadata[:datastreams].last[:id] = "Backup Batteries"
        @station.save_metadata
      end

      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end

      @station.save_observations
    end

    it "uploads the latest observations" do
      VCR.use_cassette("data_garrison/observations_upload") do
        @station.upload_observations(@sensorthings_url, "latest")

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).at_least_once
      end
    end

    it "uploads observations for a single timestamp" do
      VCR.use_cassette("data_garrison/observations_upload") do
        @station.upload_observations(@sensorthings_url, "2019-06-26T14:43:00Z")

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).at_least_once
      end
    end

    it "raises an error of the timestamp has no data cached" do
      expect {
        @station.upload_observations(@sensorthings_url, "2000-06-25T20:00:00Z")
      }.to raise_error(RuntimeError)
    end

    it "uploads filtered observations for a single timestamp with an allowed list" do
      VCR.use_cassette("data_garrison/observations_upload") do
        @station.upload_observations(@sensorthings_url, "2019-06-26T14:43:00Z", allowed: ["Pressure"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).once
      end
    end

    it "uploads filtered observations for a single timestamp with a blocked list" do
      VCR.use_cassette("data_garrison/observations_upload") do
        @station.upload_observations(@sensorthings_url, "2019-06-26T14:43:00Z", blocked: ["Pressure"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(6)
      end
    end
  end
end
