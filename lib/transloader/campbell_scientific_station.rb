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
        last_modified = parse_last_modified(response["Last-Modified"])
        data_files.push({
          filename:       File.basename(data_url),
          url:            data_url,
          last_modified:  to_iso8601(last_modified),
          initial_length: filedata.length
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
        @properties[:station_model_name]    = data[0][2]
        @properties[:station_serial_number] = data[0][3]
        @properties[:station_program]       = data[0][5]

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

      puts "\nWARNING: Latitude and Longitude unavailable from metadata."
      puts "These values must be manually added to the station metadata file."

      puts "\nWARNING: Time zone offset not available from data source."
      puts "The offset must be manually added to the station metadata file."

      puts "\nWARNING: Sensor metadata PDF or SensorML not available from data source."
      puts "The URL may be manually added to the station metadata file under the \"procedure\" key."

      # Convert to Hash
      @metadata = {
        name:            "Campbell Scientific Station #{@id}",
        description:     "Campbell Scientific Weather Station #{@id}",
        latitude:        nil,
        longitude:       nil,
        elevation:       nil,
        timezone_offset: nil,
        updated_at:      Time.now,
        procedure:       nil,
        datastreams:     datastreams,
        data_files:      data_files,
        properties:      @properties
      }
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download
    # and save to a cache file.
    def get_metadata
      if File.exist?(@metadata_path)
        @metadata = JSON.parse(IO.read(@metadata_path))
      else
        @metadata = download_metadata
        save_metadata
      end
    end

    # Connect to data provider and download Observations for a specific
    # data_file entry.
    # 
    # Return an array of observation rows:
    # [
    #   ["2019-03-05T17:00:00.000Z", {
    #     name: "TEMPERATURE_Avg",
    #     reading: 5.479
    #   }, {
    #     name: "WIND_SPEED",
    #     reading: 12.02
    #   }],
    #   ["2019-03-05T18:00:00.000Z", {
    #   ...
    #   }]
    # ]
    # TODO: convert to private method?
    def get_observations(data_file)
      data          = []
      last_modified = nil
      new_length    = nil
      observations  = []

      # Should the full remote file be downloaded, or should a partial
      # download be used instead?
      redownload = true

      # Check if file has already been downloaded, and if so use HTTP
      # Range header to only download the newest part of the file
      if data_file["last_length"]
        # Download part of file; do not use gzip compression
        redownload = false

        # TODO: Check if remote file is smaller than expected
        # redownload = true
      end
        
      if redownload
        # Download entire file; can use gzip compression
        uri = URI(data_file["url"])
        request = Net::HTTP::Get.new(uri)
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end

        filedata      = response.body
        last_modified = parse_last_modified(response["Last-Modified"])
        new_length    = filedata.length
        data          = CSV.parse(filedata)
        # Parse column headers for observed properties
        # (Skip first column with timestamp)
        column_headers = data[1].slice(1..-1)

        # Store column names in station metadata cache file, as 
        # partial requests later will not be able to know the column
        # headers.
        data_file["headers"] = column_headers
        save_metadata

        # Omit the file header rows from the next step, as the next
        # step may run from a partial file that doesn't know any
        # headers.
        data.slice!(0..3)
      end

      # Update station metadata cache
      # TODO: Update "last_length"
      # TODO: Does this actually update the file?
      data_file["last_modified"] = to_iso8601(last_modified)
      save_metadata

      # Parse observations from CSV
      data.each do |row|
        # Transform dates into ISO8601 in UTC.
        # This will make it simpler to group them by day and to simplify
        # timezones for multiple stations.
        timestamp = parse_toa5_timestamp(row[0], @metadata["timezone_offset"])
        utc_time = to_iso8601(timestamp)
        observations.push([utc_time, 
          row[1..-1].map.with_index { |x, i|
            {
              name: data_file["headers"][i],
              # Adjust null handler here
              reading: x == "NAN" ? "null" : x.to_f
            }
          }
        ])
      end
      
      observations
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
      # THING entity
      # Create Thing entity
      thing = SensorThings::Thing.new({
        name:        @metadata['name'],
        description: @metadata['description'],
        properties:  {
          provider:              'Campbell Scientific',
          station_id:            @id,
          station_model_name:    @metadata['properties']['station_model_name'],
          station_serial_number: @metadata['properties']['station_serial_number'],
          station_program:       @metadata['properties']['station_program']
        }
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata['Thing@iot.navigationLink'] = thing.link
      save_metadata

      # LOCATION entity
      # Check if latitude or longitude are blank
      if @metadata['latitude'].nil? || @metadata['longitude'].nil?
        puts "ERROR: Station latitude or longitude is nil!"
        puts "Location entity cannot be created. Exiting."
        exit(1)
      end
      
      # Create Location entity
      location = SensorThings::Location.new({
        name:         @metadata['name'],
        description:  @metadata['description'],
        encodingType: 'application/vnd.geo+json',
        location: {
          type:        'Point',
          coordinates: [@metadata['longitude'].to_f, @metadata['latitude'].to_f]
        }
      })

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata['Location@iot.navigationLink'] = location.link
      save_metadata

      # SENSOR entities
      @metadata['datastreams'].each do |stream|
        # Create Sensor entities
        sensor = SensorThings::Sensor.new({
          name:        "Campbell Scientific Station #{@id} #{stream['name']} Sensor",
          description: "Campbell Scientific Station #{@id} #{stream['name']} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata:     @metadata['procedure'] || ""
        })

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream['Sensor@iot.navigationLink'] = sensor.link
        stream['Sensor@iot.id'] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      @metadata['datastreams'].each do |stream|
        # Create Observed Property entities
        # TODO: Use mapping to improve these entities
        observed_property = SensorThings::ObservedProperty.new({
          name:        stream['name'],
          definition:  "http://example.org/#{stream['name']}",
          description: stream['name']
        })

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream['ObservedProperty@iot.navigationLink'] = observed_property.link
        stream['ObservedProperty@iot.id'] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      @metadata['datastreams'].each do |stream|
        # Create Datastream entities
        # TODO: Use mapping to improve these entities
        datastream = SensorThings::Datastream.new({
          name:        "Campbell Scientific Station #{@id} #{stream['name']}",
          description: "Campbell Scientific Station #{@id} #{stream['name']}",
          # TODO: Use mapping to improve unit of measurement
          unitOfMeasurement: {
            name:       stream['units'] || "",
            symbol:     stream['units'] || "",
            definition: ''
          },
          # TODO: Use more specific observation types, if possible
          observationType: 'http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation',
          Sensor: {
            '@iot.id' => stream['Sensor@iot.id']
          },
          ObservedProperty: {
            '@iot.id' => stream['ObservedProperty@iot.id']
          }
        })

        # Upload entity and parse response
        datastream.upload_to(thing.link)

        # Cache URL
        stream['Datastream@iot.navigationLink'] = datastream.link
        stream['Datastream@iot.id'] = datastream.id
      end

      save_metadata
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
    # TODO: data file handling must happen here, not in get_observations!
    def save_observations
      get_metadata

      @metadata["data_files"].each do |data_file|
        data_filename = data_file["filename"]
        all_observations = get_observations(data_file)

        # Group observations by date
        observations_by_day = all_observations.group_by do |set|
          # Split the ISO8601 string to just the date
          # Example key: "2019-03-05T17:00:00.000Z"
          set[0].split("T")[0]
        end

        observations_by_day.each do |date, observations|
          # Save observations as CSV file
          
          year, month, day = date.split("-")
          obs_dir = "#{@observations_path}/#{data_filename}/#{year}/#{month}"
          obs_filename = "#{obs_dir}/#{day}.csv"
          FileUtils.mkdir_p(obs_dir)

          # If the observations file doesn't exist, convert the
          # observations to CSV and dump to the file.
          # If the file DOES exist, then it needs to be read and the
          # observations from file merged with the new observations.
          if File.exist?(obs_filename)
            # TODO: open file, read values, merge and sort observations
            # array
          end

          CSV.open(obs_filename, "wb") do |csv|
            # Add header row
            csv << ["timestamp"].concat(data_file["headers"])

            # take observations and make an array of readings for the 
            # CSV file.
            # Example observations item:
            # ["2018-08-05T15:00:00.000-0700", [{
            #   name: "", reading: ""
            #  }, {...}]]
            observations.each do |set|
              csv << set[1].collect { |i| i[:reading] }
            end
          end
          
        end
        
        # Update station metadata cache file with observation date range

      end

    end

    # For parsing functionality specific to this data provider
    private

    # Convert Time class to ISO8601 string with fractional seconds
    def to_iso8601(time)
      time.strftime("%FT%T.%L%z")
    end

    # Convert Last-Modified header String to Time class.
    # Assumes nginx date format: "%a, %d %b %Y %H:%M:%S %Z"
    def parse_last_modified(time)
      Time.strptime(time, "%a, %d %b %Y %T %Z")
    end

    # Convert a TOA5 timestamp String to a Time class.
    # An ISO8601 time zone offset (e.g. "-07:00") is required.
    def parse_toa5_timestamp(time, zone_offset)
      Time.strptime(time + "#{zone_offset}", "%F %T%z")
    end
  end
end
