require 'csv'
require 'net/http'
require 'uri'

module Transloader
  class CampbellScientificStation

    attr_accessor :id, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @user_id = @properties[:user_id]
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{CampbellScientificProvider::CACHE_DIRECTORY}/metadata/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{CampbellScientificProvider::CACHE_DIRECTORY}/#{@id}"
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream
    def download_metadata
      # Check for data files
      data_urls = @properties[:data_urls]

      if data_urls.empty?
        puts "ERROR: No data URLs specified."
        puts "Data URLs are required to download station metadata. Exiting."
        exit 1
      end

      data_files = []
      datastreams = []

      data_urls.each do |data_url|
        # Download CSV
        # TODO: Extract HTTP work to its own class
        uri = URI(data_url)
        request = Net::HTTP::Get.new(uri)
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end

        filedata = response.body
        data = CSV.parse(filedata)
        
        # Store CSV file metadata
        # 
        # Cannot use "Content-Length" here as the request has been
        # encoded by gzip, which is enabled by default for Ruby 
        # net/http.
        last_modified = Time.strptime(response["Last-Modified"], "%a, %d %b %Y %H:%M:%S %Z")
        data_files.push({
          filename: File.basename(data_url),
          url: data_url,
          last_modified: last_modified.strftime("%FT%H:%M:%S.%L%z"),
          last_length: filedata.length
        })

        # Parse CSV headers for station metadata
        # 
        # Row 1:
        # 1. File Type
        # 2. Station Name
        # 3. Model Name
        # 4. Serial Number
        # 5. Logger OS Version
        # 6. Logger Program
        # 7. Logger Program Signature
        # 8. Table Name
        # 
        # Note: It is possible that different files may have different
        # station metadata values. We are assuming that all data files
        # are from the same station/location and that the values are not
        # different between data files.
        @properties[:station_model_name]  = data[0][2]
        @properties[:station_serial_name] = data[0][3]
        @properties[:station_program]     = data[0][5]

        # Parse CSV column headers for datastreams, units
        # 
        # Row 2:
        # 1. Timestamp
        # 2+ (Observed Property)
        # Row 3:
        # Unit or Data Type
        # Row 4:
        # Observation Type (peak value, average value)
        # (WVc is Wind Vector Cell, probably)
        data[1].slice(1..-1).each_with_index do |col, index|
          datastreams.push({
            name: col,
            units: data[2][1+index],
            type: data[3][1+index]
          })
        end
      end

      # Convert to Hash
      @metadata = {
        name:        "Campbell Scientific Station #{@id}",
        description: "Campbell Scientific Weather Station #{@id}",
        latitude:    nil,
        longitude:   nil,
        elevation:   nil,
        updated_at:  Time.now,
        datastreams: datastreams,
        data_files:  data_files,
        properties:  @properties
      }
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
      if File.exist?(@metadata_path)
        @metadata = JSON.parse(IO.read(@metadata_path))
      else
        @metadata = download_metadata
        save_metadata
      end
    end

    # Connect to data provider and download Observations
    def get_observations
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
    end

    # Upload station observations for `date` to the SensorThings API 
    # server at `destination`. If `date` is "latest", then the most 
    # recent cached observation file is used.
    def put_observations(destination, date)
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      FileUtils.mkdir_p(File.dirname(@metadata_path))
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end

    # Save the observations to file cache
    def save_observations
    end

    # For parsing functionality specific to this data provider
    private
  end
end
