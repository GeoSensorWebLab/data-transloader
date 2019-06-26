require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'

module Transloader
  class EnvironmentCanadaStation
    include SemanticLogger::Loggable

    NAMESPACES = {
      'gml' => 'http://www.opengis.net/gml',
      'om' => 'http://www.opengis.net/om/1.0',
      'po' => 'http://dms.ec.gc.ca/schema/point-observation/2.0',
      'xlink' => 'http://www.w3.org/1999/xlink'
    }
    OBSERVATIONS_URL = "http://dd.weather.gc.ca/observations/swob-ml/latest/"

    attr_accessor :id, :metadata, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties.merge({
        provider: "Environment Canada"
      })
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{EnvironmentCanadaProvider::CACHE_DIRECTORY}/metadata/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{EnvironmentCanadaProvider::CACHE_DIRECTORY}/#{@id}"
    end

    # Parse metadata from the Provider properties and the SWOB-ML file for a
    # metadata hash.
    def download_metadata
      xml = observation_xml

      # Extract results from XML, use to build metadata needed for Sensor/
      # Observed Property/Datastream
      datastreams = xml.xpath('//om:result/po:elements/po:element', NAMESPACES).collect do |node|
        {
          name: node.xpath('@name').text,
          uom: node.xpath('@uom').text
        }
      end

      # Convert to Hash
      @metadata = {
        name: "Environment Canada Station #{@id}",
        description: "Environment Canada Weather Station #{@properties["Name"]}",
        elevation: xml.xpath('//po:element[@name="stn_elev"]', NAMESPACES).first.attribute('value').value,
        updated_at: Time.now,
        datastreams: datastreams,
        procedure: xml.xpath('//om:procedure/@xlink:href', NAMESPACES).text,
        properties: @properties
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

    # Connect to Environment Canada and download SWOB-ML
    def get_observations
      case @properties['AUTO/MAN']
      when "AUTO", "Auto", "Manned/Auto"
        type = "AUTO"
      when "MAN", "Manned"
        type = "MAN"
      else
        logger.error "Error: unknown station type"
        raise
      end

      swobml_url = URI.join(OBSERVATIONS_URL, "#{@id}-#{type}-swob.xml")
      response = Net::HTTP.get_response(swobml_url)

      if response.code != '200'
        logger.error "Error downloading station observation data"
        raise
      end
      response.body
    end

    # Return the XML document object for the SWOB-ML file. Will cache the
    # object.
    def observation_xml
      @xml ||= Nokogiri::XML(get_observations())
    end

    # Upload metadata to SensorThings API
    def upload_metadata(server_url)
      # THING entity
      # Create Thing entity
      thing = SensorThings::Thing.new({
        name:        @metadata[:name],
        description: @metadata[:description],
        properties:  @metadata[:properties]
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:'Thing@iot.navigationLink'] = thing.link
      save_metadata

      # LOCATION entity
      # Create Location entity
      location = SensorThings::Location.new({
        name:         @metadata[:name],
        description:  @metadata[:description],
        encodingType: 'application/vnd.geo+json',
        location: {
          type:        'Point',
          coordinates: [@metadata[:properties][:Longitude].to_f, @metadata[:properties][:Latitude].to_f]
        }
      })

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:'Location@iot.navigationLink'] = location.link
      save_metadata

      # SENSOR entities
      @metadata[:datastreams].each do |stream|
        # Create Sensor entities
        sensor = SensorThings::Sensor.new({
          name:        "Station #{@id} #{stream[:name]} Sensor",
          description: "Environment Canada Station #{@id} #{stream[:name]} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata:     @metadata[:procedure]
        })

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:'Sensor@iot.navigationLink'] = sensor.link
        stream[:'Sensor@iot.id'] = sensor.id
      end

      save_metadata

      # OBSERVED PROPERTY entities
      @metadata[:datastreams].each do |stream|
        # Create Observed Property entities
        # TODO: Use mapping to improve these entities
        observed_property = SensorThings::ObservedProperty.new({
          name:        stream[:name],
          definition:  "http://example.org/#{stream[:name]}",
          description: stream[:name]
        })

        # Upload entity and parse response
        observed_property.upload_to(server_url)

        # Cache URL
        stream[:'ObservedProperty@iot.navigationLink'] = observed_property.link
        stream[:'ObservedProperty@iot.id'] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      @metadata[:datastreams].each do |stream|
        # Create Datastream entities
        # TODO: Use mapping to improve these entities
        datastream = SensorThings::Datastream.new({
          name:        "Station #{@id} #{stream[:name]}",
          description: "Environment Canada Station #{@id} #{stream[:name]}",
          # TODO: Use mapping to improve unit of measurement
          unitOfMeasurement: {
            name:       stream[:uom],
            symbol:     '',
            definition: ''
          },
          # TODO: Use more specific observation types, if possible
          observationType: 'http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation',
          Sensor: {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty: {
            '@iot.id' => stream[:'ObservedProperty@iot.id']
          }
        })

        # Upload entity and parse response
        datastream.upload_to(thing.link)

        # Cache URL
        stream[:'Datastream@iot.navigationLink'] = datastream.link
        stream[:'Datastream@iot.id'] = datastream.id
      end

      save_metadata
    end

    # Upload station observations for `date` to the SensorThings API server at
    # `destination`. If `date` is "latest", then the most recent SWOB-ML file
    # is used.
    def upload_observations(destination, date)
      logger.info "Uploading observations for #{date} to #{destination}"

      # Check for metadata
      if @metadata.empty?
        logger.error "station metadata not loaded"
        raise
      end

      # Check for cached datastream URLs
      @metadata[:datastreams].each do |stream|
        if stream[:'Datastream@iot.navigationLink'].nil?
          logger.error "Datastream navigation URLs not cached"
          raise
        end
      end

      # Check for cached observations at date
      if !Dir.exist?(@observations_path)
        logger.error "observation cache directory does not exist"
        raise
      end

      if date == "latest"
        begin
          year_dir = Dir.entries(@observations_path).sort.last
          month_dir = Dir.entries(File.join(@observations_path, year_dir)).sort.last
          day_dir = Dir.entries(File.join(@observations_path, year_dir, month_dir)).sort.last
          filename = Dir.entries(File.join(@observations_path, year_dir, month_dir, day_dir)).sort.last
        rescue
          logger.error "Could not locate latest observation cache file"
          raise
        end

        file_path = File.join(@observations_path, year_dir, month_dir, day_dir, filename)
      else
        locate_date = DateTime.parse(date)
        file_path = File.join(@observations_path, locate_date.strftime('%Y/%m/%d/%H%M%S%z.xml'))

        if !File.exist?(file_path)
          logger.error "Could not locate desired observation cache file: #{file_path}"
          raise
        end
      end

      logger.info "Uploading observations from #{file_path}"

      xml = observation_xml
      @metadata[:datastreams].each do |datastream|
        datastream_url = datastream[:'Datastream@iot.navigationLink']
        datastream_name = datastream[:name]


        if xml.xpath("//om:result/po:elements/po:element[@name='#{datastream_name}']", NAMESPACES).empty?
          # The result is not in this SWOB-ML document, perhaps not reported
          # during this reporting interval. In that case, no Observation is
          # created.
        else
          # OBSERVATION entity
          # Create Observation entity
          # TODO: Coerce result type based on datastream observation type

          result = xml.xpath("//om:result/po:elements/po:element[@name='#{datastream_name}']/@value", NAMESPACES).text

          # SensorThings API does not like an empty string, instead "null" string
          # should be used.
          if result == ""
            logger.info "Found null for #{datastream_name}"
            result = "null"
          end

          observation = SensorThings::Observation.new({
            phenomenonTime: xml.xpath('//om:samplingTime/gml:TimeInstant/gml:timePosition', NAMESPACES).text,
            result: result,
            resultTime: xml.xpath('//om:resultTime/gml:TimeInstant/gml:timePosition', NAMESPACES).text
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end

    # Save the SWOB-ML file to file cache
    def save_observations
      xml = observation_xml

      # Parse date from SWOB-ML
      timestamp = DateTime.parse(xml.xpath('//po:identification-elements/po:element[@name="date_tm"]/@value', NAMESPACES).text)

      # Create cache directory structure
      date_path = timestamp.strftime('%Y/%m/%d')
      time_path = timestamp.strftime('%H%M%S%z.xml')
      FileUtils.mkdir_p("#{@observations_path}/#{date_path}")

      # Dump XML to file
      IO.write("#{@observations_path}/#{date_path}/#{time_path}", xml.to_s)
    end
  end
end
