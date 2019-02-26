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
        name: "Data Garrison Station #{@id}",
        description: "Data Garrison Weather Station #{@id}",
        latitude: nil,
        longitude: nil,
        elevation: nil,
        updated_at: nil,
        datastreams: datastream_metadata,
        transceiver: transceiver_metadata,
        logger: logger_metadata,
        download_links: download_links,
        properties: @properties
      }
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
    end

    # Connect to Environment Canada and download SWOB-ML
    def get_observations
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
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
