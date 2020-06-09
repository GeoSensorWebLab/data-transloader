require 'transloader'

require 'rspec'
require 'vcr'

RSpec.describe Transloader::EnvironmentCanadaStation do

  before(:each) do
    reset_cache($cache_dir)
    @database_url = "file://#{$cache_dir}"
    @http_client  = Transloader::HTTP.new
    @station_id   = "CXCM"
  end

  def build_station
    Transloader::EnvironmentCanadaStation.new(
      database_url: @database_url,
      http_client:  @http_client,
      id:           @station_id
    )
  end

  ##############
  # Get Metadata
  ##############

  context "Downloading Metadata" do
    it "downloads the stations list" do
      VCR.use_cassette("environment_canada/stations") do
        station = build_station()
        station.download_metadata

        expect(WebMock).to have_requested(:get,
          Transloader::EnvironmentCanadaStation::METADATA_URL).times(1)
      end
    end

    it "raises an error when the stations list cannot be downloaded" do
      VCR.use_cassette("environment_canada/stations_not_found") do
        station = build_station()

        expect {
          station.download_metadata
        }.to raise_error(Transloader::HTTPError, /Error downloading station list/)
      end
    end

    it "raises an error when the stations list file has moved" do
      VCR.use_cassette("environment_canada/stations_redirect") do
      station = build_station()
      expect {
        station.download_metadata
      }.to raise_error(Transloader::HTTPError, /Error downloading station list/)
    end
    end

    it "downloads the station metadata when saving the metadata" do
      VCR.use_cassette("environment_canada/stations") do
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be false

        station = build_station()
        station.download_metadata

        expect(WebMock).to have_requested(:get,
          "https://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml").times(1)
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be true
      end
    end

    it "raises an error when the SWOB-ML file cannot be found" do
      VCR.use_cassette("environment_canada/observations_not_found") do
        station = build_station()

        expect {
          station.download_metadata
        }.to raise_error(Transloader::HTTPError, /SWOB-ML file not found/)
      end
    end

    it "follows a redirect when the SWOB-ML file has moved" do
      VCR.use_cassette("environment_canada/observations_redirect") do
        station = build_station()
        station.download_metadata

        expect(WebMock).to have_requested(:get,
          "https://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml").times(1)
        expect(File.exist?("#{$cache_dir}/environment_canada/metadata/CXCM.json")).to be true
      end
    end
  end

  ##############
  # Put Metadata
  ##############

  context "Uploading Metadata" do
    # pre-create the station for this context block
    before(:each) do
      @station = nil

      VCR.use_cassette("environment_canada/stations") do
        @station = build_station()
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
      @station          = nil
      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"

      VCR.use_cassette("environment_canada/stations") do
        @station = build_station()
        @station.download_metadata
      end

      VCR.use_cassette("environment_canada/metadata_upload") do
        @station.upload_metadata(@sensorthings_url)
      end
    end

    it "downloads the latest data by default" do
      VCR.use_cassette("environment_canada/stations") do
        expect(WebMock).to have_requested(:get,
          "https://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml")
          .times(1)

        @station.download_observations

        expect(WebMock).to have_requested(:get,
          "https://dd.weather.gc.ca/observations/swob-ml/latest/CXCM-AUTO-swob.xml")
          .times(2)
      end
    end

    # TODO: Download historical to data store
    # TODO: Returns an error if no historical data is available to download
  end

  ##################
  # Put Observations
  ##################

  # SPECIAL NOTE
  # When re-recording these "VCR" interactions, the testing STA server
  # MUST have a blank slate! This applies to each test in this context
  # separately!
  context "Uploading Observations" do
    # pre-create the station for this context block
    before(:each) do
      @station          = nil
      @sensorthings_url = "http://192.168.33.77:8080/FROST-Server/v1.0/"
      # When re-recording the VCR interactions, this date interval
      # MUST be updated to the current date/time.
      @interval = "2019-06-09T00:00:00Z/2020-06-09T23:59:59Z"
    end

    it "filters entities uploaded in an interval according to an allow list" do
      VCR.use_cassette("environment_canada/observations_upload_interval_allowed") do
        allowed_list = ["min_batry_volt_pst1hr"]

        @station = build_station()
        @station.download_metadata
        @station.upload_metadata(@sensorthings_url, {
          allowed: allowed_list
        })
        @station.download_observations

        @station.upload_observations(@sensorthings_url, @interval,
          allowed: allowed_list)

        expect(WebMock).to have_requested(:post,
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(1)
      end
    end

    it "filters entities uploaded in an interval according to a block list" do
      VCR.use_cassette("environment_canada/observations_upload_interval_blocked") do
        # By blocking more of the datastreams, the size of the VCR files
        # are reduced.
        blocked_list = [
            "max_batry_volt_pst1hr", "min_batry_volt_pst1hr", "hdr_fwd_pwr",
            "hdr_refltd_pwr", "hdr_suply_volt", "hdr_oscil_drft",
            "logr_panl_temp", "rel_hum", "avg_air_temp_pst1hr",
            "max_air_temp_pst1hr", "max_rel_hum_pst1hr", "min_air_temp_pst1hr",
            "min_rel_hum_pst1hr", "avg_wnd_spd_10m_pst10mts",
            "avg_wnd_dir_10m_pst10mts", "avg_wnd_spd_10m_pst1hr",
            "avg_wnd_dir_10m_pst1hr", "max_wnd_spd_10m_pst1hr",
            "max_wnd_spd_pst1hr_tm", "wnd_dir_10m_pst1hr_max_spd",
            "max_wnd_spd_10m_pst10mts", "wnd_dir_10m_pst10mts_max_spd",
            "avg_wnd_spd_10m_pst2mts", "avg_wnd_dir_10m_pst2mts",
            "avg_wnd_spd_pcpn_gag_pst10mts", "stn_pres",
            "avg_cum_pcpn_gag_wt_fltrd_pst5mts", "pcpn_amt_pst1hr",
            "avg_snw_dpth_pst5mts", "rnfl_amt_pst1hr",
            "tot_globl_solr_radn_pst1hr", "pcpn_amt_pst3hrs",
            "pcpn_snc_last_syno_hr", "pcpn_amt_pst6hrs", "max_air_temp_pst6hrs",
            "min_air_temp_pst6hrs", "pcpn_amt_pst24hrs", "max_air_temp_pst24hrs",
            "min_air_temp_pst24hrs", "pres_tend_amt_pst3hrs",
            "pres_tend_char_pst3hrs", "dwpt_temp", "mslp", "wetblb_temp",
            "avg_cum_pcpn_gag_wt_fltrd_pst5mts_1",
            "avg_cum_pcpn_gag_wt_fltrd_pst5mts_2",
            "avg_cum_pcpn_gag_wt_fltrd_pst5mts_3"
        ]

        @station = build_station()
        @station.download_metadata
        @station.upload_metadata(@sensorthings_url, {
          blocked: blocked_list
        })
        @station.download_observations


        @station.upload_observations(@sensorthings_url, @interval,
          blocked: blocked_list)

        expect(WebMock).to have_requested(:post,
          %r[#{@sensorthings_url}Datastreams\(\d+\)/Observations]).times(2)
      end
    end
  end
end
