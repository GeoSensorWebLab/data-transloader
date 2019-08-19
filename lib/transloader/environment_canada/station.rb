require 'nokogiri'
require 'time'
require 'transloader/station_methods'

module Transloader
  class EnvironmentCanadaStation
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    NAMESPACES = {
      'gml'   => 'http://www.opengis.net/gml',
      'om'    => 'http://www.opengis.net/om/1.0',
      'po'    => 'http://dms.ec.gc.ca/schema/point-observation/2.0',
      'xlink' => 'http://www.w3.org/1999/xlink'
    }
    OBSERVATIONS_URL = "http://dd.weather.gc.ca/observations/swob-ml"

    attr_accessor :id, :metadata, :properties, :provider

    def initialize(options = {})
      @data_store     = options[:data_store]
      @http_client    = options[:http_client]
      @id             = options[:id]
      @metadata_store = options[:metadata_store]
      @provider       = options[:provider]
      @properties     = options[:properties].merge({
        provider: "Environment Canada"
      })
      @metadata          = {}
      @ontology          = EnvironmentCanadaOntology.new
      @entity_factory    = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Parse metadata from the Provider properties and the SWOB-ML file for a
    # metadata hash.
    # If `override_metadata` is specified, it is merged on top of the 
    # downloaded metadata before being cached.
    def download_metadata(override_metadata = {})
      xml = get_observation_xml

      # Extract results from XML, use to build metadata needed for Sensor/
      # Observed Property/Datastream
      datastreams = xml.xpath('//om:result/po:elements/po:element', NAMESPACES).collect do |node|
        {
          name: node.xpath('@name').text,
          uom:  node.xpath('@uom').text
        }
      end

      # Convert to Hash
      @metadata = {
        name:        "Environment Canada Station #{@id}",
        description: "Environment Canada Weather Station #{@properties["Name"]}",
        elevation:   xml.xpath('//po:element[@name="stn_elev"]', NAMESPACES).first.attribute('value').value,
        updated_at:  Time.now,
        datastreams: datastreams,
        procedure:   xml.xpath('//om:procedure/@xlink:href', NAMESPACES).text,
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
        properties:  @metadata[:properties]
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:'Thing@iot.navigationLink'] = thing.link
      save_metadata

      # LOCATION entity
      # Create Location entity
      location = @entity_factory.new_location({
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
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = @entity_factory.new_sensor({
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
      datastreams.each do |stream|
        # Look up entity in ontology;
        # if nil, then use default attributes
        entity = @ontology.observed_property(stream[:name])

        if entity.nil?
          logger.warn "No Observed Property found in Ontology for EnvironmentCanada:#{stream[:name]}"
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
        stream[:'ObservedProperty@iot.navigationLink'] = observed_property.link
        stream[:'ObservedProperty@iot.id'] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        # Look up UOM, observationType in ontology;
        # if nil, then use default attributes
        uom = @ontology.unit_of_measurement(stream[:name])

        if uom.nil?
          logger.warn "No Unit of Measurement found in Ontology for EnvironmentCanada:#{stream[:name]} (#{stream[:uom]})"
          uom = {
            name:       stream[:uom],
            symbol:     '',
            definition: ''
          }
        end

        observation_type = observation_type_for(stream[:name], @ontology)

        datastream = @entity_factory.new_datastream({
          name:        "Station #{@id} #{stream[:name]}",
          description: "Environment Canada Station #{@id} #{stream[:name]}",
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
        datastream.upload_to(thing.link)

        # Cache URL
        stream[:'Datastream@iot.navigationLink'] = datastream.link
        stream[:'Datastream@iot.id'] = datastream.id
      end

      save_metadata
    end

    # Download observations from the provider for this station in
    # `interval`. If `interval` is nil, only the latest will be
    # downloaded. Observations will be sent to the DataStore.
    # TODO: Support interval download
    def download_observations(interval = nil)
      get_metadata
      xml = get_observation_xml

      if xml.nil?
        logger.error "Unable to download SWOB-ML"
        raise
      end

      # Parse date from SWOB-ML
      timestamp = Time.parse(xml.xpath('//po:identification-elements/po:element[@name="date_tm"]/@value', NAMESPACES).text)

      # New data store
      observations = xml.xpath("//om:result/po:elements/po:element", NAMESPACES).collect do |element|
        {
          timestamp: timestamp,
          result: element.at_xpath("@value", NAMESPACES).text,
          property: element.at_xpath("@name", NAMESPACES).text,
          unit: element.at_xpath("@uom", NAMESPACES).text
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




    private

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

    # Return the XML document object for the SWOB-ML file.
    # If `timestamp` is `nil`, then the latest SWOB-ML file will be used.
    # If `timestamp` is specified, then the *closest* SWOB-ML to that
    # timestamp will be downloaded.
    # If no SWOB-ML is available, `nil` is returned.
    def get_observation_xml(timestamp = nil)
      data = get_swob_data(timestamp)
      data && Nokogiri::XML(data)
    end

    # Connect to Environment Canada and download the SWOB-ML data that
    # is closest to `timestamp`. If `timestamp` is `nil`, then the 
    # latest SWOB-ML will be used. Otherwise, the SWOB-ML closest to the
    # timestamp will be returned. If the SWOB-ML is unavailable, `nil`
    # is returned.
    # 
    # Note that SWOB-ML files may be delayed in reporting, so trying to
    # get 0900 would fail as it may be at 0905 instead. To solve this,
    # this method will try to get the next closest SWOB-ML file after
    # `timestamp`.
    # 
    # Note 2: Minutely SWOB-ML files are currently **not used**.
    def get_swob_data(timestamp = nil)
      if timestamp.nil?
        # Download latest data
        url = "#{OBSERVATIONS_URL}/latest"
        get_swob_data_from_url(url)
      else
        # Determine if SWOB-ML is available for day

      end
    end

    # Download the hourly SWOB-ML file in the `url` directory.
    # "AUTO" or "MANNED" will be determined automatically from the
    # station metadata.
    def get_swob_data_from_url(url)
      case @properties['AUTO/MAN']
      when "AUTO", "Auto", "Manned/Auto"
        type = "AUTO"
      when "MAN", "Manned"
        type = "MAN"
      else
        logger.error "Error: unknown station type"
        raise
      end

      swobml_url = "#{url}/#{@id}-#{type}-swob.xml"
      response = @http_client.get(uri: swobml_url)

      if response.code != '200'
        logger.error "Error downloading station observation data"
        raise
      end
      response.body
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

      # Observation from DataStore:
      # * timestamp
      # * result
      # * property
      # * unit
      observations.each do |observation|
        datastream = datastreams.find { |datastream|
          datastream[:name] == observation[:property]
        }

        if datastream.nil?
          logger.warn "No datastream found for observation property: #{observation[:property]}"
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            logger.error "Datastream navigation URLs not cached"
            raise
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
    end
  end
end
