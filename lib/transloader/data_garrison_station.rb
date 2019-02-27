require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'pry'
require 'set'

module Transloader
  class DataGarrisonStation

    attr_accessor :id, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @user_id = @properties[:user_id]
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/metadata/#{@user_id}/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/#{@user_id}/#{@id}"
      @base_path = "https://datagarrison.com/users/#{@user_id}/#{@id}/index.php"
    end

    # Download and extract metadata from HTML, use to build metadata 
    # needed for Sensor/Observed Property/Datastream
    def download_metadata
      html = station_metadata_html

      if html.internal_subset.external_id != "-//W3C//DTD HTML 4.01 Transitional//EN"
        puts "WARNING: Page is not HTML 4.01 Transitional, and may have been updated"
        puts "since this tool was created. Parsing may fail, proceed with caution."
      end

      unit_id = html.xpath('/html/body/table/tr/td/table/tr/td/font')[0].text.to_s
      unit_id = unit_id[/Unit (?<id>\d+)/, "id"]

      if @id != unit_id
        puts "WARNING: id does not match unit id"
      end

      # Parse the time from the "Latest Conditions" element
      # e.g. 02/22/19 8:28 pm
      # No time zone information is available, it is local time for the
      # station.
      raw_phenomenon_time = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td/table/tr[position()=1]').text.to_s
      raw_phenomenon_time = raw_phenomenon_time[/\d{2}\/\d{2}\/\d{2} \d{1,2}:\d{2} (am|pm)/]
      phenomenon_time = DateTime.strptime(raw_phenomenon_time, '%m/%d/%y %l:%M %P')

      # Parse number of sensors
      raw_sensors_list = html.xpath('/html/body/table/tr[position()=2]/td/table/tr/td/table/tr[position()=last()]').text.to_s
      raw_sensors_list = raw_sensors_list[/(\d+ sensors(\W+\w+)+)/]

      sensor_count = raw_sensors_list[/(\d+) sensors/, 1].to_i
      sensors = {}
      sensor_types = raw_sensors_list[/\d+ sensors(.+)/, 1].scan(/\w+/) do |matched|
        property = matched.strip
        sensors[property] = {}
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
        puts "\nWARNING: Multiple sensors have the same ID: #{list}"
        puts "This must be manually corrected in the station metadata file."
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

      puts "\nWARNING: Latitude and Longitude unavailable from metadata."
      puts "These values must be manually added to the station metadata file."

      # Convert to Hash
      @metadata = {
        'name'           => "Data Garrison Station #{@id}",
        'description'    => "Data Garrison Weather Station #{@id}",
        'latitude'       => nil,
        'longitude'      =>  nil,
        'elevation'      =>  nil,
        'updated_at'     =>  nil,
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
        'datastreams'    =>  datastream_metadata,
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
        'transceiver'    =>  transceiver_metadata,
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
        'logger'         =>  logger_metadata,
        'download_links' =>  download_links,
        'properties'     =>  @properties
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

    # Connect to Data Garrison and download Observations
    def get_observations
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
      # THING entity
      # Create Thing entity
      thing = Thing.new({
        name:        @metadata['name'],
        description: @metadata['description'],
        properties:  {
          logger:      @metadata['logger'],
          provider:    "Data Garrison",
          station_id:  @id,
          station_url: @base_path,
          transceiver: @metadata['transceiver'],
          user_id:     @user_id
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
      location = Location.new({
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
        sensor = Sensor.new({
          name:        "Station #{@id} #{stream['id']} Sensor",
          description: "Data Garrison Station #{@id} #{stream['id']} Sensor",
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
        stream['Sensor@iot.navigationLink'] = sensor.link
        stream['Sensor@iot.id'] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      @metadata['datastreams'].each do |stream|
        # Create Observed Property entities
        # TODO: Use mapping to improve these entities
        observed_property = ObservedProperty.new({
          name:        stream['id'],
          definition:  "http://example.org/#{stream['id']}",
          description: stream['id']
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
        datastream = Datastream.new({
          name:        "Station #{@id} #{stream['id']}",
          description: "Data Garrison Station #{@id} #{stream['id']}",
          # TODO: Use mapping to improve unit of measurement
          unitOfMeasurement: {
            name:       stream['Units'] || "",
            symbol:     stream['Units'] || "",
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

    # Upload station observations for `date` to the SensorThings API server at
    # `destination`. If `date` is "latest", then the most recent SWOB-ML file
    # is used.
    def put_observations(destination, date)
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      FileUtils.mkdir_p(File.dirname(@metadata_path))
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end

    # Save the SWOB-ML file to file cache
    def save_observations
    end

    # For parsing functionality specific to Data Garrison
    private

    # Return the HTML document object for the station. Will cache the
    # object.
    def station_metadata_html
      @html ||= Nokogiri::HTML(open("sample.html"))
    end
  end
end
