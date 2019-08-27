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
        @station.download_metadata

        expect(WebMock).to have_requested(:get, 
          %r[https://datagarrison\.com/users/300234063581640/300234065673960/index\.php.+])
          .times(1)
        expect(File.exist?(metadata_file)).to be true
      end
    end

    it "downloads information about data files" do
      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.download_metadata

        expect(WebMock).to have_requested(:get, 
          %r[https://datagarrison\.com/users/300234063581640/300234065673960/index\.php.+])
          .times(1)
        
        expect(WebMock).to have_requested(:head,
          "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
          .times(1)
        expect(WebMock).to have_requested(:head,
          "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_002.txt")
          .times(1)
        expect(WebMock).to have_requested(:head,
          "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_003.txt")
          .times(1)
        expect(WebMock).to have_requested(:head,
          "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_004.txt")
          .times(1)

        expect(@station.metadata[:data_files]).to_not be_nil
        expect(@station.metadata[:data_files].length).to eq(4)
      end
    end

    it "raises an error if metadata source file cannot be downloaded" do
      VCR.use_cassette("data_garrison/station_not_found") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        expect {
          @station.download_metadata
        }.to raise_error(RuntimeError, "Could not download station data")
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
        @station.download_metadata
        # These values must be fixed before uploading to STA.
        @station.metadata[:datastreams].last[:name] = "Backup Batteries"
        @station.download_metadata(override_metadata: {
          latitude: 69.158,
          longitude: -107.0403,
          timezone_offset: "-06:00",
          datastreams: @station.metadata[:datastreams]
        }, overwrite: true)
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
          .with(body: /Volt/).at_least_once
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
        @station.download_metadata
        # These values must be fixed before uploading to STA.
        @station.metadata[:datastreams].last[:name] = "Backup Batteries"
        @station.download_metadata(override_metadata: {
          latitude: 69.158,
          longitude: -107.0403,
          timezone_offset: "-06:00",
          datastreams: @station.metadata[:datastreams]
        }, overwrite: true)
      end

      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end
    end

    it "converts downloaded observations and stores in DataStore" do
      VCR.use_cassette("data_garrison/observations_download") do
        expect(@station.data_store.get_all_in_range(Time.new(2000), Time.now).length).to eq(0)
        @station.download_observations
        expect(@station.data_store.get_all_in_range(Time.new(2000), Time.now).length).to_not eq(0)        
      end
    end

    context "when the data file's 'last_length' has not been set" do
      before(:each) do
        @station.metadata[:data_files][0][:last_length] = nil
      end

      it "downloads and parses the entire data file" do
        VCR.use_cassette("data_garrison/observations_download") do
          @station.download_observations

          expect(WebMock).to have_requested(:get, 
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .with(headers: { 'Range' => '' }).times(1)
          expect(WebMock).to have_requested(:get, 
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_002.txt")
            .with(headers: { 'Range' => '' }).times(1)
          expect(WebMock).to have_requested(:get, 
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_003.txt")
            .with(headers: { 'Range' => '' }).times(1)
          expect(WebMock).to have_requested(:get, 
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/Test_Launch_004.txt")
            .with(headers: { 'Range' => '' }).times(1)
        end
      end

      it "updates the last_modified and last_length after a download" do
        VCR.use_cassette("data_garrison/observations_download") do
          @station.download_observations

          expect(@station.metadata[:data_files][0][:last_length]).to_not be_nil
          expect(@station.metadata[:data_files][0][:last_modified]).to_not be_nil
        end
      end
    end

    context "when the 'last_length' has been cached" do
      before(:each) do
        # Only test with first data file, to simplify specs
        @station.metadata[:data_files] = @station.metadata[:data_files].slice(0, 1)
        @station.metadata[:data_files][0][:last_length] = 0
        # If this is not set, then the ETL doesn't know how to map row
        # values to datastreams.
        @station.metadata[:data_files][0][:headers] = [
          "Temperature_9986750_deg_C"
        ]
      end

      it "executes a HEAD request for the updated Content-Length" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          expect(WebMock).to have_requested(:head,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .times(2)

          @station.metadata[:data_files][0][:last_length] = 1
          @station.download_observations

          expect(WebMock).to have_requested(:head,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .times(3)
        end
      end

      it "redownloads the entire data file if Content-Length is shorter than expected" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          @station.metadata[:data_files][0][:last_length] = 999999999
          @station.download_observations

          expect(WebMock).to have_requested(:head,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .times(3)
          expect(WebMock).to have_requested(:get,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .with(headers: { 'Range' => '' })
            .times(1)
        end
      end

      it "executes no GET request when the Content-Length is equal" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          @station.metadata[:data_files][0][:last_length] = 7377
          @station.download_observations

          expect(WebMock).to have_requested(:head,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .times(3)
          expect(WebMock).to have_requested(:get,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .with(headers: { 'Range' => '' })
            .times(0)
        end
      end

      it "executes a partial GET when the Content-Length has increased" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          @station.metadata[:data_files][0][:last_length] = 100
          @station.download_observations

          expect(WebMock).to have_requested(:head,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .times(3)
          expect(WebMock).to have_requested(:get,
            "https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt")
            .with(headers: { 'Range' => 'bytes=100-' })
            .times(1)
        end
      end

      it "returns new observations when the server responds 206" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          @station.metadata[:data_files][0][:last_length] = 0
          @station.download_observations
          observations = @station.data_store.get_all_in_range(Time.new(2000), Time.new(2019, 9, 1))
          expect(observations.length).to_not eq(0)
        end
      end

      it "updates the last_modified and last_length after a download" do
        VCR.use_cassette("data_garrison/observations_download_partial") do
          @station.metadata[:data_files][0][:last_length] = 0
          @station.download_observations
          
          expect(@station.metadata[:data_files][0][:last_length]).to_not eq(0)
          expect(@station.metadata[:data_files][0][:last_modified]).to_not be_nil
        end
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

      VCR.use_cassette("data_garrison/station") do
        @provider = Transloader::DataGarrisonProvider.new($cache_dir, @http_client)
        @station = @provider.get_station(
          user_id: "300234063581640",
          station_id: "300234065673960"
        )
        @station.download_metadata
        # These values must be fixed before uploading to STA.
        @station.metadata[:datastreams].last[:name] = "Backup Batteries"
        @station.download_metadata(override_metadata: {
          latitude: 69.158,
          longitude: -107.0403,
          timezone_offset: "-06:00",
          datastreams: @station.metadata[:datastreams]
        }, overwrite: true)
      end

      VCR.use_cassette("data_garrison/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end

      VCR.use_cassette("data_garrison/observations_download") do
        @station.download_observations
      end
    end

    it "uploads observations for a single time range" do
      VCR.use_cassette("data_garrison/observations_upload") do
        @station.upload_observations(@sensorthings_url, "2018-08-01T00:00:00Z/2018-09-01T00:00:00Z")

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(162)
      end
    end

    it "uploads filtered observations for a single timestamp with an allowed list" do
      VCR.use_cassette("data_garrison/observations_upload_allowed") do
        @station.upload_observations(@sensorthings_url, "2018-08-01T00:00:00Z/2018-09-01T00:00:00Z", allowed: ["Pressure"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(27)
      end
    end

    it "uploads filtered observations for a single timestamp with a blocked list" do
      VCR.use_cassette("data_garrison/observations_upload_blocked") do
        @station.upload_observations(@sensorthings_url, "2018-08-01T00:00:00Z/2018-09-01T00:00:00Z", blocked: ["Pressure"])

        expect(WebMock).to have_requested(:post, 
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(162)
      end
    end
  end
end
