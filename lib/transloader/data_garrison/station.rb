require 'nokogiri'
require 'set'
require 'time'

module Transloader
  class DataGarrisonStation
    include SemanticLogger::Loggable

    attr_accessor :id, :metadata, :properties, :provider

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
    def download_metadata(override_metadata = nil)
      html = get_station_data_html

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
      datastreams = @metadata[:datastreams]

      if options[:allowed]
        datastreams = datastreams.filter do |datastream|
          options[:allowed].include?(datastream[:name])
        end
      elsif options[:blocked]
        datastreams = datastreams.filter do |datastream|
          !options[:blocked].include?(datastream[:name])
        end
      end

      # THING entity
      # Create Thing entity
      thing = @entity_factory.new_thing({
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
      location = @entity_factory.new_location({
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
        sensor = @entity_factory.new_sensor({
          name:        "Station #{@id} #{stream[:name]} Sensor",
          description: "Data Garrison Station #{@id} #{stream[:name]} Sensor",
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
        entity = @ontology.observed_property(stream[:name])

        if entity.nil?
          logger.warn "No Observed Property found in Ontology for DataGarrison:#{stream[:name]}"
          entity = {
            name:        stream[:name],
            definition:  "http://example.org/#{stream[:name]}",
            description: stream[:name]
          }
        end

        observed_property = @entity_factory.new_observed_property(entity)

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
        uom = @ontology.unit_of_measurement(stream[:name])

        if uom.nil?
          logger.warn "No Unit of Measurement found in Ontology for DataGarrison:#{stream[:name]} (#{stream[:uom]})"
          uom = {
            name:       stream[:Units] || "",
            symbol:     stream[:Units] || "",
            definition: ''
          }
        end

        observation_type = observation_type_for(stream[:name])

        datastream = @entity_factory.new_datastream({
          name:        "Station #{@id} #{stream[:name]}",
          description: "Data Garrison Station #{@id} #{stream[:name]}",
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

    # Connect to Data Garrison and download Observations
    # TODO: Support interval download
    def download_observations(interval = nil)
      get_metadata
      html = get_station_data_html

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
      phenomenon_time     = Time.strptime(raw_phenomenon_time, '%m/%d/%y %l:%M %P %Z')
      utc_time            = phenomenon_time.to_time.utc
      readings            = parse_readings_from_html(html)

      # Observation:
      # * timestamp
      # * result
      # * property
      # * unit
      observations = readings.collect do |reading|
        {
          timestamp: utc_time,
          result:    reading[:result],
          property:  reading[:name],
          unit:      reading[:units]
        }
      end

      @data_store.store(observations)
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

      upload_observations_array(observations, options)
    end



    # For parsing functionality specific to Data Garrison
    private

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

      if response.code != "200"
        raise "Could not download station data"
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

    def observation_type_for(property)
      @ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
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
        logger.error "station metadata not loaded"
        raise
      end

      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = @metadata[:datastreams]

      if options[:allowed]
        datastreams = datastreams.filter do |datastream|
          options[:allowed].include?(datastream[:name])
        end
      elsif options[:blocked]
        datastreams = datastreams.filter do |datastream|
          !options[:blocked].include?(datastream[:name])
        end
      end

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
      observations.each do |observation|
        datastream = datastream_hash[observation[:property]]

        if datastream.nil?
          logger.warn "No datastream found for observation property: #{observation[:property]}"
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            logger.error "Datastream navigation URLs not cached"
            raise
          end

          phenomenonTime = Time.parse(observation[:timestamp]).iso8601(3)
          result = observation[:result]

          observation = @entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result: result,
            resultTime: phenomenonTime
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end
    end
  end
end
