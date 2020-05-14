require 'nokogiri'
require 'set'
require 'time'
require 'transloader/station_methods'
require 'uri'

module Transloader
  # Class for downloading and uploading metadata and observation data
  # from Data Garrison's online weather station data portal. The data is
  # downloaded over HTTP, and the data has a custom format. As the site
  # has no REST API, custom endpoints must be called to force an update
  # of the data files to download.
  # 
  # This class is called by the main Transloader::Station class.
  class DataGarrisonStation
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    NAME      = "Data Garrison Station"
    LONG_NAME = "Data Garrison Weather Station"

    attr_accessor :data_store, :id, :metadata, :properties, :provider

    def initialize(options = {})
      @data_store        = options[:data_store]
      @http_client       = options[:http_client]
      @id                = options[:id]
      @metadata_store    = options[:metadata_store]
      @provider          = options[:provider]
      @properties        = options[:properties]
      @user_id           = @properties[:user_id]
      @metadata          = {}
      @base_path         = "https://datagarrison.com/users/#{@user_id}/#{@id}/index.php?sens_details=127&details=7"
      @ontology          = DataGarrisonOntology.new
      @entity_factory    = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream.
    # If `override_metadata` is specified, it is merged on top of the 
    # downloaded metadata before being cached.
    def download_metadata(override_metadata: nil, overwrite: false)
      if (@metadata_store.metadata != {} && !overwrite)
        logger.warn "Existing metadata found, will not overwrite."
        return false
      end

      html = get_station_data_html

      unit_id = html.xpath('/html/body/table/tr/td/table/tr/td/font')[0].text.to_s
      unit_id = unit_id[/Unit (?<id>\d+)/, "id"]

      if @id != unit_id
        logger.warn "id does not match unit id"
      end

      data_files = []

      # Parse download links into data files
      html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td[position()=2]/div[position()=2]/table/tr[position()=2]/td/table/tr/td/font/a').collect do |element|
        href       = element.attr('href')
        data_desc  = element.text.to_s
        filename   = data_desc.sub(/ /, '_')

        if filename == ""
          # Without a filename, the file cannot be downloaded as a TSV
          logger.debug "Skipping data file with missing filename (station #{@id})"
        else
          # Data Garrison uses incremental indexes on data files each
          # time the weather station is initialized.
          file_index   = href[/data_launch=(\d+)/, 1]
          fi_justified = file_index.rjust(3, '0')
          datafile_url = "https://datagarrison.com/users/#{@user_id}/#{@id}/temp/#{filename}_#{fi_justified}.txt"

          # Trigger an update using by accessing the download.php script
          request_updated_data(file_index: file_index, filename: data_desc)

          # Issue HEAD request for data files
          response = @http_client.head(uri: datafile_url)
          last_modified = parse_last_modified(response["Last-Modified"])

          # Content-Length can be used here because there is no 
          # compression encoding.
          data_files.push(DataFile.new({
            datafileindex: file_index,
            datafilename:  data_desc,
            last_modified: to_iso8601(last_modified),
            length:        response["Content-Length"],
            url:           datafile_url
          }).to_h)
        end
      end

      logger.debug "Found #{data_files.length} valid data files."

      # Parse sensor metadata
      # It is possible for some sensors to have the same name, which is
      # incorrect but happens. This must be manually corrected in the
      # metadata cache file.
      station_metadata = []
      raw_metadata = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td[position()=2]/div[position()=2]/table/tr[position()=3]/td/p').text.to_s

      raw_metadata.split(/      |\n/).each do |matched|
        # remove any non-breaking spaces
        matched.gsub!(/ /, '')

        # Match headers and create a new metadata section object
        case matched
        when /-Transceiver/
          station_metadata.push({name: "transceiver"})
        when /-Logger/
          station_metadata.push({name: "logger"})
        when /-Sensors/
        when /^-([^-]+)/
          station_metadata.push({name: $1})
        else
          # Match sub-section objects
          last = station_metadata[-1]
          m = matched.match(/(?<key>[^:]+): (?<value>.+)/)
          if m
            last[m['key'].strip] = m['value'].strip
          end
        end
      end

      # Print warning if multiple sensors have the same ID
      sensor_ids = station_metadata.collect { |i| i[:name] }
      if sensor_ids.count != sensor_ids.uniq.count
        # Use a Set to find which ones are duplicates
        s = Set.new
        list = sensor_ids.find_all { |e| !s.add?(e) }.join(", ")
        logger.warn "WARNING: Multiple sensors have the same ID: #{list}"
        logger.warn "This must be manually corrected in the station metadata file."
      end

      transceiver_metadata = {}
      logger_metadata = {}
      datastream_metadata = []

      station_metadata.each do |meta|
        case meta[:name]
        when "transceiver"
          transceiver_metadata = meta
        when "logger"
          logger_metadata = meta
        else
          datastream_metadata.push(meta)
        end
      end

      logger.warn "WARNING: Latitude and Longitude unavailable from metadata."
      logger.warn "These values must be manually added to the station metadata file."

      logger.warn "WARNING: Time zone offset not available from data source."
      logger.warn "The offset must be manually added to the station metadata file."

      # Convert to Hash
      @metadata = {
        name: "#{NAME} #{@id}",
        description: "#{LONG_NAME} #{@id}",
        latitude: nil,
        longitude: nil,
        elevation: nil,
        timezone_offset: nil,
        updated_at: nil,
        # example datastream item:
        # {
        #   "id": "Pressure",
        #   "Units": "mbar",
        #   "Resolution": "12 bit",
        #   "Part number": "S-BPA-XXXX",
        #   "Range": "660.000 to 1069.400mbar",
        #   "Serial number": "3513109",
        #   "Sub and serial number": "3513109"
        # }
        datastreams:  datastream_metadata,
        # example transceiver metadata:
        # {
        #   "id": "transceiver",
        #   "ID": "300234065673960",
        #   "Status": "active",
        #   "Power level": "100 %",
        #   "Transmission interval": "every 120 minutes",
        #   "Mode": "standby unless power falls below 75 %",
        #   "Low power alarm": "triggers if power falls below 30 %",
        #   "Sensor alarm(s)": "on",
        #   "Network": "Satellite",
        #   "Board revision": "0xA0"
        # }
        transceiver:  transceiver_metadata,
        # example logger metadata:
        # {
        #   "id": "logger",
        #   "Serial number": "20301990",
        #   "Logging start": "08/12/18 10:58 am local time",
        #   "Logging interval": "every 15.00 minutes",
        #   "Sampling interval": "off",
        #   "Launch description": "Test Launch",
        #   "Part number": "S-BPA-XXXX",
        #   "Data start address": "1105",
        #   "Logging power": "Yes"
        # }
        logger:  logger_metadata,
        data_files:  data_files,
        properties:  @properties
      }

      if !override_metadata.nil?
        @metadata.merge!(override_metadata)
      end

      save_metadata
    end

    # Upload metadata to SensorThings API
    # * server_url: URL endpoint of SensorThings API
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will be
    #              uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              be uploaded to STA.
    # 
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_metadata(server_url, options = {})
      get_metadata

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

      # THING entity
      # Create Thing entity
      thing = build_thing({
        logger:      @metadata[:logger],
        provider:    "Data Garrison",
        station_id:  @id,
        station_url: @base_path,
        transceiver: @metadata[:transceiver],
        user_id:     @user_id
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:"Thing@iot.navigationLink"] = thing.link
      save_metadata

      # LOCATION entity
      # Check if latitude or longitude are blank
      if @metadata[:latitude].nil? || @metadata[:longitude].nil?
        raise Error, <<-EOH
        Station latitude or longitude is nil!
        Location entity cannot be created. Exiting.
        EOH
      end
      
      # Create Location entity
      location = build_location()

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:"Location@iot.navigationLink"] = location.link
      save_metadata

      # SENSOR entities
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = build_sensor("Station #{@id} #{stream[:name]} Sensor", "#{NAME} #{@id} #{stream[:name]} Sensor")

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:"Sensor@iot.navigationLink"] = sensor.link
        stream[:"Sensor@iot.id"] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      datastreams.each do |stream|
        # Create an Observed Property based on the datastream, using the
        # Ontology if available.
        observed_property = build_observed_property(stream[:name])

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream[:"ObservedProperty@iot.navigationLink"] = observed_property.link
        stream[:"ObservedProperty@iot.id"] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        datastream_name  = stream[:name]
        uom              = uom_for_datastream(datastream_name, stream[:Units])
        observation_type = observation_type_for(datastream_name, @ontology)

        datastream = @entity_factory.new_datastream({
          name:              "Station #{@id} #{datastream_name}",
          description:       "#{NAME} #{@id} #{datastream_name}",
          unitOfMeasurement: uom,
          observationType:   observation_type,
          Sensor:            {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty:  {
            '@iot.id' => stream[:'ObservedProperty@iot.id']
          }
        })

        # Upload entity and parse response
        datastream.upload_to(thing.link, false)

        # Cache URL
        stream[:"Datastream@iot.navigationLink"] = datastream.link
        stream[:"Datastream@iot.id"] = datastream.id
      end

      save_metadata
    end

    # Connect to Data Garrison and download Observations
    # Interval download does nothing as there is no way to currently
    # extract a range from the Data Garrison data files.
    def download_observations(interval = nil)
      if !interval.nil?
        logger.warn "Interval download for observations is unsupported for Data Garrison"
      end

      get_metadata
      
      @metadata[:data_files].each do |data_file|
        data_filename = data_file[:filename]
        all_observations = download_observations_for_file(data_file).sort { |a,b| a[0] <=> b[0] }

        # Store Observations in DataStore.
        # 
        # Convert to new store format first:
        # * timestamp
        # * result
        # * property
        # * unit
        observations = all_observations.collect do |observation_set|
          timestamp = Time.parse(observation_set[0])
          # observation:
          # * name (property)
          # * reading (result)
          observation_set[1].collect do |observation|
            # For HOBO Weather Station data, the TSV file headers 
            # include the Datastream names as a substring.
            datastream = @metadata[:datastreams].find do |datastream|
              observation[:name].include?(datastream[:name])
            end

            if datastream
              {
                timestamp: timestamp,
                result: observation[:reading],
                property: datastream[:name],
                unit: datastream[:units]
              }
            else
              nil
            end
          end
        end
        observations.flatten! && observations.compact!
        logger.info "Downloaded Observations: #{observations.count}"
        @data_store.store(observations)
      end
    end

    # Collect all the observation files in the date interval, and upload
    # them.
    # 
    # * destination: URL endpoint of SensorThings API
    # * interval: ISO8601 <start>/<end> interval
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will have
    #              observations uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              have observations be uploaded to STA.
    # 
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_observations(destination, interval, options = {})
      get_metadata

      time_interval = Transloader::TimeInterval.new(interval)
      observations  = @data_store.get_all_in_range(time_interval.start, time_interval.end)
      logger.info "Uploading Observations: #{observations.count}"
      upload_observations_array(observations, options)
    end



    # For parsing functionality specific to Data Garrison
    private

    # Connect to data provider and download Observations for a specific
    # data_file entry.
    # 
    # Return an array of observation rows:
    # [
    #   ["2019-03-05T17:00:00.000Z", {
    #     name: "Temperature_20305795_deg_C",
    #     reading: 22.441
    #   }, {
    #     name: "Pressure_20290325_mbar",
    #     reading: 928.950
    #   }],
    #   ["2019-03-05T18:00:00.000Z", {
    #   ...
    #   }]
    # ]
    # 
    # TODO: Parse time zone offsets for each data file and store in 
    # metadata, which means metadata would not need to be manually 
    # edited.
    def download_observations_for_file(data_file)
      request_updated_data(file_index: data_file[:datafileindex], filename: data_file[:datafilename])

      download = partial_download_url(
        url: data_file[:url],
        offset: data_file[:last_length])

      data         = []
      observations = []

      # If full file was downloaded, parse from beginning. Otherwise
      # only parse extract of file.
      if download[:body] && download[:full_file]
        data = CSV.parse(download[:body], col_sep: "\t")
        # Parse column headers for observed properties.
        # For HOBO Weather Station TSV files, headers are on line 3.
        # We use slice to skip the first column with "Date_Time"
        column_headers = data[2].slice(1..-1)

        # Store column names in station metadata cache file, as 
        # partial requests later will not be able to know the column
        # headers.
        data_file[:headers] = column_headers.compact!
        save_metadata

        # Omit the file header rows from the next step, as the next
        # step may run from a partial file that doesn't know any
        # headers. HOBO Weather Station TSV files have 3 header rows.
        data.slice!(0..3)
      elsif download[:body]
        # TODO: Improve parsing by excluding partial rows
        begin
          data = CSV.parse(download[:body], col_sep: "\t")
        rescue CSV::MalformedCSVError => e
          logger.error "Could not parse partial response data.", e
        end
      end

      # Update station metadata cache with what the server says is the
      # latest file update time and the latest file length in bytes
      data_file[:last_modified] = to_iso8601(download[:last_modified])
      data_file[:last_length]   = download[:content_length]
      save_metadata

      # Parse observations from TSV
      data.each do |row|
        # Transform dates into ISO8601 in UTC.
        # This will make it simpler to group them by day and to simplify
        # timezones for multiple stations.
        # HOBO Weather Station Example: "08/12/18 10:58:07"
        begin
          timestamp = Time.strptime(row[0] + @metadata[:timezone_offset], 
            "%m/%d/%y %H:%M:%S%z")
          utc_time = to_iso8601(timestamp)
          observations.push([utc_time, 
            row[1..-1].map.with_index { |x, i|
              {
                name: data_file[:headers][i],
                reading: x
              }
            }
          ])
        rescue Exception => e
          logger.warn "Skipping parsing of line: #{e}"
        end
      end
      
      observations
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
      @metadata = @metadata_store.metadata
      if (@metadata == {})
        @metadata = download_metadata
        save_metadata
      end
    end

    # Use the HTTP wrapper to fetch the base path and return the 
    # response body.
    def get_station_data
      response = @http_client.get(uri: @base_path)

      if response.code == "301"
        # Follow permanent redirects
        response = @http_client.get(uri: response["Location"])
      elsif response.code != "200"
        raise HTTPError.new(response, "Could not download station data")
      end

      response.body
    end

    # Return the HTML document object for the station. Will cache the
    # object.
    def get_station_data_html
      @html ||= Nokogiri::HTML(get_station_data)

      if @html.internal_subset.external_id != "-//W3C//DTD HTML 4.01 Transitional//EN"
        logger.warn <<-EOH
        Page is not HTML 4.01 Transitional, and may have been updated
        since this tool was created. Parsing may fail, proceed with caution.
        EOH
      end

      @html
    end

    # Returns an array of Reading Hashes.
    # Reading (symbol keys):
    # * id (property)
    # * result
    # * units
    def parse_readings_from_html(html)
      readings = []
      html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td/table/tr').each_with_index do |element, i|
        # Skip empty elements, "Latest Conditions" element, and "Station 
        # Status" element. They all start with a blank line.
        text = element.text
        if !text.match?(/^\W$/)
          # replace all non-breaking space characters
          text.gsub!(/ /, ' ')

          # Special case for parsing wind speed/gust/direction
          if text.match?(/Wind Speed/)
            text.match(/Wind Speed: (\S+) (\S+) Gust: (\S+) (\S+) Direction: (\S+) \((\d+)o\)/) do |m|
              readings.push({
                name:   "Wind Speed",
                result: m[1].to_f,
                units:  m[2]
              }, {
                name:   "Gust Speed",
                result: m[3].to_f,
                units:  m[4]
              }, {
                name:   "Wind Direction",
                result: m[6].to_f,
                units:  "deg"
              })
            end
          else
            # Only "Pressure", "Temperature", "RH", "Backup Batteries"
            # are supported!
            text.match(/^\s+(Pressure|Temperature|RH|Backup Batteries)\s(\S+)\W(.+)$/) do |m|
              readings.push({
                name:   m[1],
                result: m[2].to_f,
                units:  m[3]
              })
            end
          end
        end
      end

      readings
    end

    # For one of this station's data files, request the download.php
    # script that updates the TSV file so we can download the newest
    # observations later.
    def request_updated_data(file_index:, filename:)
      # The time at which to "start" the data files, in seconds of 
      # UNIX Epoch time. We default to the year 2000.
      data_start   = Time.utc(2000, 1, 1).to_i
      # The time at which to "end" the data files, in seconds of 
      # UNIX Epoch time. We default to "now".
      data_end     = Time.now.to_i
      base         = "https://datagarrison.com/users/#{@user_id}/#{@id}"
      # type=2 updates the TSV file
      download_url = "#{base}/download.php?data_launch=#{file_index}&data_start=#{data_start}&data_end=#{data_end}&data_desc=#{URI::encode(filename)}&utc=0&type=2"

      # Issue GET request to force-update the data files
      update_response = @http_client.get(uri: download_url)

      if update_response.code != "200"
        raise HTTPError.new(update_response, "Error updating Data Garrison TSV file")
      end
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      @metadata_store.merge(@metadata)
    end

    # Upload all observations in an array.
    # * observations: Array of DataStore observations
    # * options: Hash
    #   * allowed: Array of strings, only matching properties will have
    #              observations uploaded to STA.
    #   * blocked: Array of strings, only non-matching properties will
    #              have observations be uploaded to STA.
    # 
    # If `allowed` and `blocked` are both defined, then `blocked` is
    # ignored.
    def upload_observations_array(observations, options = {})
      # Check for metadata
      if @metadata.empty?
        raise Error, "station metadata not loaded"
      end

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

      # Create hash map of observed properties to datastream URLs.
      # This is used to determine where Observation entities are 
      # uploaded.
      datastream_hash = datastreams.reduce({}) do |memo, datastream|
        memo[datastream[:name]] = datastream
        memo
      end

      # Observation from DataStore:
      # * timestamp
      # * result
      # * property
      # * unit
      responses = observations.collect do |observation|
        datastream = datastream_hash[observation[:property]]

        if datastream.nil?
          logger.warn "No datastream found for observation property: #{observation[:property]}"
          :unavailable
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            raise Error, "Datastream navigation URLs not cached"
          end

          phenomenonTime = Time.parse(observation[:timestamp]).iso8601(3)
          result = coerce_result(observation[:result], observation_type_for(datastream[:name], @ontology))

          observation = @entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result: result,
            resultTime: phenomenonTime
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end

      # output info on how many observations were created and so on
      log_response_types(responses)
    end
  end
end
