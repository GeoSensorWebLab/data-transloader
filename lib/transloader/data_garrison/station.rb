require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'
require 'time'

module Transloader
  class DataGarrisonStation
    include SemanticLogger::Loggable

    attr_accessor :id, :metadata, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @user_id = @properties[:user_id]
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/metadata/#{@user_id}/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/#{@user_id}/#{@id}"
      @base_path = "https://datagarrison.com/users/#{@user_id}/#{@id}/index.php?sens_details=127&details=7"
      @ontology = DataGarrisonOntology.new
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream
    def download_metadata
      html = station_data_html

      unit_id = html.xpath('/html/body/table/tr/td/table/tr/td/font')[0].text.to_s
      unit_id = unit_id[/Unit (?<id>\d+)/, "id"]

      if @id != unit_id
        logger.warn "id does not match unit id"
      end

      # Parse download links
      # These aren't used yet, but are cached for future use
      # e.g. https://datagarrison.com/users/300234063581640/300234065673960/temp/MYC_001.txt
      download_links = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td[position()=2]/div[position()=2]/table/tr[position()=2]/td/table/tr/td/font/a').collect do |element|
        href = element.attr('href')
        filename = element.text.to_s.sub(/ /, '_')
        file_index = href[/data_launch=(\d+)/, 1].rjust(3, '0')
        {
          data_start: href[/data_start=(\d+)/, 1],
          data_end: href[/data_end=(\d+)/, 1],
          filename: filename,
          index: file_index,
          download_url: "https://datagarrison.com/users/#{@user_id}/#{@id}/temp/#{filename}_#{file_index}.txt"
        }
      end

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
          station_metadata.push({id: "transceiver"})
        when /-Logger/
          station_metadata.push({id: "logger"})
        when /-Sensors/
        when /^-([^-]+)/
          station_metadata.push({id: $1})
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
      sensor_ids = station_metadata.collect { |i| i[:id] }
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
        case meta[:id]
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
        name: "Data Garrison Station #{@id}",
        description: "Data Garrison Weather Station #{@id}",
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
        download_links:  download_links,
        properties:  @properties
      }
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
      if File.exist?(@metadata_path)
        @metadata = JSON.parse(IO.read(@metadata_path), symbolize_names: true)
      else
        @metadata = download_metadata
        save_metadata
      end
    end

    # Connect to Data Garrison and download Observations
    def get_observations
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

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = @metadata[:datastreams]

      if options[:allowed]
        datastreams = datastreams.filter do |datastream|
          options[:allowed].include?(datastream[:id])
        end
      elsif options[:blocked]
        datastreams = datastreams.filter do |datastream|
          !options[:blocked].include?(datastream[:id])
        end
      end

      # THING entity
      # Create Thing entity
      thing = SensorThings::Thing.new({
        name:        @metadata[:name],
        description: @metadata[:description],
        properties:  {
          logger:      @metadata[:logger],
          provider:    "Data Garrison",
          station_id:  @id,
          station_url: @base_path,
          transceiver: @metadata[:transceiver],
          user_id:     @user_id
        }
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:"Thing@iot.navigationLink"] = thing.link
      save_metadata

      # LOCATION entity
      # Check if latitude or longitude are blank
      if @metadata[:latitude].nil? || @metadata[:longitude].nil?
        raise <<-EOH
        Station latitude or longitude is nil!
        Location entity cannot be created. Exiting.
        EOH
      end
      
      # Create Location entity
      location = SensorThings::Location.new({
        name:         @metadata[:name],
        description:  @metadata[:description],
        encodingType: 'application/vnd.geo+json',
        location: {
          type:        'Point',
          coordinates: [@metadata[:longitude].to_f, @metadata[:latitude].to_f]
        }
      })

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:"Location@iot.navigationLink"] = location.link
      save_metadata

      # SENSOR entities
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = SensorThings::Sensor.new({
          name:        "Station #{@id} #{stream[:id]} Sensor",
          description: "Data Garrison Station #{@id} #{stream[:id]} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata:     @base_path
        })

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:"Sensor@iot.navigationLink"] = sensor.link
        stream[:"Sensor@iot.id"] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      datastreams.each do |stream|
        # Look up entity in ontology;
        # if nil, then use default attributes
        entity = @ontology.observed_property(stream[:id])

        if entity.nil?
          logger.warn "No Observed Property found in Ontology for DataGarrison:#{stream[:id]}"
          entity = {
            name:        stream[:id],
            definition:  "http://example.org/#{stream[:id]}",
            description: stream[:id]
          }
        end

        observed_property = SensorThings::ObservedProperty.new(entity)

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream[:"ObservedProperty@iot.navigationLink"] = observed_property.link
        stream[:"ObservedProperty@iot.id"] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        # Look up UOM, observationType in ontology;
        # if nil, then use default attributes
        uom = @ontology.unit_of_measurement(stream[:id])

        if uom.nil?
          logger.warn "No Unit of Measurement found in Ontology for DataGarrison:#{stream[:id]} (#{stream[:uom]})"
          uom = {
            name:       stream[:Units] || "",
            symbol:     stream[:Units] || "",
            definition: ''
          }
        end

        observation_type = observation_type_for(stream[:id])

        datastream = SensorThings::Datastream.new({
          name:        "Station #{@id} #{stream[:id]}",
          description: "Data Garrison Station #{@id} #{stream[:id]}",
          unitOfMeasurement: uom,
          observationType: observation_type,
          Sensor: {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty: {
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

    # Upload station observations for `date` to the SensorThings API 
    # server at `destination`. If `date` is "latest", then the most 
    # recent cached observation file is used.
    def upload_observations(destination, date)
      get_metadata
      logger.info "Uploading observations for #{date} to #{destination}"

      # Check for cached datastream URLs
      @metadata[:datastreams].each do |stream|
        if stream[:"Datastream@iot.navigationLink"].nil?
          raise "Datastream navigation URLs not cached"
        end
      end

      # Check for cached observations at date
      if !Dir.exist?(@observations_path)
        raise "observation cache directory does not exist"
      end

      if date == "latest"
        begin
          year_dir  = Dir.entries(@observations_path).sort.last
          month_dir = Dir.entries(File.join(@observations_path, year_dir)).sort.last
          day_dir   = Dir.entries(File.join(@observations_path, year_dir, month_dir)).sort.last
          filename  = Dir.entries(File.join(@observations_path, year_dir, month_dir, day_dir)).sort.last
        rescue
          raise "Could not locate latest observation cache file"
        end

        file_path = File.join(@observations_path, year_dir, month_dir, day_dir, filename)
      else
        locate_date = Time.parse(date)
        file_path = File.join(@observations_path, locate_date.strftime('%Y/%m/%d/%H%M%SZ.html'))

        if !File.exist?(file_path)
          raise "Could not locate desired observation cache file: #{file_path}"
        end
      end

      logger.info "Uploading observations from #{file_path}"
      upload_observations_from_file(file_path)
    end

    def upload_observations_from_file(file)
      html = Nokogiri::HTML(open(file))

      # Parse the time from the "Latest Conditions" element
      # e.g. 02/22/19 8:28 pm
      raw_phenomenon_time = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td/table/tr[position()=1]').text.to_s
      raw_phenomenon_time = raw_phenomenon_time[/\d{2}\/\d{2}\/\d{2} \d{1,2}:\d{2} (am|pm)/]
      # append the time zone from the metadata cache file
      raw_phenomenon_time = raw_phenomenon_time + @metadata[:timezone_offset]
      phenomenon_time = Time.strptime(raw_phenomenon_time, '%m/%d/%y %l:%M %P %Z')

      # Parse latest readings
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
                "id"     => "Wind Speed",
                "result" => m[1].to_f,
                "units"  => m[2]
              }, {
                "id"     => "Gust Speed",
                "result" => m[3].to_f,
                "units"  => m[4]
              }, {
                "id"     => "Wind Direction",
                "result" => m[6].to_f,
                "units"  => "deg"
              })
            end
          else
            # Only "Pressure", "Temperature", "RH", "Backup Batteries"
            # are supported!
            text.match(/^\s+(Pressure|Temperature|RH|Backup Batteries)\s(\S+)\W(.+)$/) do |m|
              readings.push({
                "id"     => m[1],
                "result" => m[2].to_f,
                "units"  => m[3]
              })
            end
          end
        end
      end

      @metadata[:datastreams].each do |datastream|
        datastream_url = datastream[:"Datastream@iot.navigationLink"]
        datastream_name = datastream[:id]

        # OBSERVATION entity
        # Create Observation entity

        reading = readings.find { |r| r["id"] == datastream_name }
        result = reading["result"]

        # Coerce result type based on datastream observation type
        result = coerce_result(result, observation_type_for(datastream_name))

        # SensorThings API does not like an empty string, instead "null"
        # string should be used.
        if result == ""
          logger.info "Found null for #{datastream_name}"
          result = "null"
        end

        # The time string is manually created here as a mis-match 
        # between the client and server on the usage of fractional 
        # seconds will cause existing server-side Observation entities 
        # to not be re-used.
        # By default, Ruby's ISO8601 function will not include 
        # fractional seconds.
        # Times are also coerced to UTC for the server.
        time = phenomenon_time.to_time.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        observation = SensorThings::Observation.new({
          phenomenonTime: time,
          result: result,
          resultTime: time
        })

        # Upload entity and parse response
        observation.upload_to(datastream_url)
      end
    end

    # Collect all the observation files in the date interval, and upload
    # them.
    # (Kind of wish I had a database here.)
    def upload_observations_in_interval(destination, interval)
      time_interval = Transloader::TimeInterval.new(interval)
      start_time = time_interval.start.utc
      end_time = time_interval.end.utc

      matching_years = Dir.entries(@observations_path).reduce([]) do |memo, year_dir|
        if year_dir.to_i >= start_time.year && year_dir.to_i <= end_time.year
          memo.push("#{@observations_path}/#{year_dir}")
        end
        memo
      end

      matching_months = matching_years.collect do |year_dir|
        Dir.entries(year_dir).reduce([]) do |memo, month_dir|
          if month_dir.to_i >= start_time.month && month_dir.to_i <= end_time.month
            memo.push("#{year_dir}/#{month_dir}")
          end
          memo
        end
      end.flatten

      matching_days = matching_months.collect do |month_dir|
        Dir.entries(month_dir).reduce([]) do |memo, day_dir|
          if day_dir.to_i >= start_time.day && day_dir.to_i <= end_time.day
            memo.push("#{month_dir}/#{day_dir}")
          end
          memo
        end
      end.flatten

      day_files = matching_days.collect do |day_dir|
        Dir.entries(day_dir).collect do |file|
          "#{day_dir}/#{file}"
        end
      end.flatten

      # Filter files in time interval
      output = day_files.reduce([]) do |memo, file|
        if !(file.end_with?("/.") || file.end_with?("/.."))
          parts = file.split("/")
          year = parts[-4]
          month = parts[-3]
          day = parts[-2]
          time = parts[-1].split(".")[0]
          timestamp = Time.parse("#{year}#{month}#{day}T#{time}").utc
          if (timestamp >= start_time && timestamp <= end_time)
            memo.push(file)
          end
        end
        memo
      end

      output.each do |file|
        upload_observations_from_file(file)
      end
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      FileUtils.mkdir_p(File.dirname(@metadata_path))
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end

    # Save the webpage observations to file cache
    def save_observations
      get_metadata
      html = station_data_html

      # Parse the time from the "Latest Conditions" element
      # e.g. 02/22/19 8:28 pm
      raw_phenomenon_time = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td/table/tr[position()=1]').text.to_s
      raw_phenomenon_time = raw_phenomenon_time[/\d{2}\/\d{2}\/\d{2} \d{1,2}:\d{2} (am|pm)/]
      # append the time zone from the metadata cache file
      if raw_phenomenon_time.nil?
        logger.error "Could not parse observation time"
        raise "Could not parse observation time"
      end
      raw_phenomenon_time = raw_phenomenon_time + @metadata[:timezone_offset]
      phenomenon_time = Time.strptime(raw_phenomenon_time, '%m/%d/%y %l:%M %P %Z')
      utc_time = phenomenon_time.to_time.utc

      # Create cache directory structure
      date_path = utc_time.strftime('%Y/%m/%d')
      time_path = utc_time.strftime('%H%M%SZ.html')
      FileUtils.mkdir_p("#{@observations_path}/#{date_path}")

      # Dump HTML to file
      IO.write("#{@observations_path}/#{date_path}/#{time_path}", html.to_s)
    end

    # For parsing functionality specific to Data Garrison
    private

    # Use the HTTP wrapper to fetch the base path and return the 
    # response body.
    def get_base_path_body
      response = Transloader::HTTP.get(uri: @base_path)

      if response.code != "200"
        raise "Could not download station data"
      end

      response.body
    end

    # Return the HTML document object for the station. Will cache the
    # object.
    def station_data_html
      # TODO: Add HTTP error handling
      @html ||= Nokogiri::HTML(get_base_path_body)

      if @html.internal_subset.external_id != "-//W3C//DTD HTML 4.01 Transitional//EN"
        logger.warn <<-EOH
        Page is not HTML 4.01 Transitional, and may have been updated
        since this tool was created. Parsing may fail, proceed with caution.
        EOH
      end

      @html
    end

    def observation_type_for(property)
      @ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
    end

    # Use the observation_type to convert result to float, int, or 
    # string.
    def coerce_result(result, observation_type)
      case observation_type
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement"
        result.to_f
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_CountObservation"
        result.to_i
      else # OM_Observation, any other type
        result
      end
    end
  end
end
