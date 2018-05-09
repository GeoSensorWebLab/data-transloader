module Transloader
  class EnvironmentCanadaStation
    NAMESPACES = {
      'gml' => 'http://www.opengis.net/gml',
      'om' => 'http://www.opengis.net/om/1.0',
      'po' => 'http://dms.ec.gc.ca/schema/point-observation/2.0',
      'xlink' => 'http://www.w3.org/1999/xlink'
    }
    OBSERVATIONS_URL = "http://dd.weather.gc.ca/observations/swob-ml/latest/"

    attr_accessor :id, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{EnvironmentCanadaProvider::CACHE_DIRECTORY}/metadata/#{@id}.json"
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
        description: "Environment Canada Weather Station #{@properties["EN name"]}",
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
        @metadata = JSON.parse(IO.read(@metadata_path))
      else
        @metadata = download_metadata
        save
      end
    end

    # Connect to Environment Canada and download SWOB-ML
    def get_observations
      case @properties['AUTO/MAN']
      when "Auto", "Manned/Auto"
        type = "AUTO"
      when "Manned"
        type = "MAN"
      else
        raise "Error: unknown station type"
      end

      swobml_url = URI.join(OBSERVATIONS_URL, "C#{@id}-#{type}-swob.xml")
      response = Net::HTTP.get_response(swobml_url)

      raise "Error downloading station observation data" if response.code != '200'
      response.body
    end

    # Return the XML document object for the SWOB-ML file. Will cache the
    # object.
    def observation_xml
      @xml ||= Nokogiri::XML(get_observations())
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
      # THING entity
      # Create Thing entity
      thing = Thing.new({
        name:        @metadata['name'],
        description: @metadata['description'],
        properties:  @metadata['properties']
      })

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata['Thing@iot.navigationLink'] = thing.link
      save_metadata

      # LOCATION entity
      # Create Location entity
      location = Location.new({
        name:         @metadata['name'],
        description:  @metadata['description'],
        encodingType: 'application/vnd.geo+json',
        location: {
          type:        'Point',
          coordinates: [@metadata['properties']['Longitude'].to_f, @metadata['properties']['Latitude'].to_f]
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
          name:        "Station #{@id} #{stream['name']} Sensor",
          description: "Environment Canada Station #{@id} #{stream['name']} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata:     @metadata['procedure']
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
        datastream = Datastream.new({
          name:        "Station #{@id} #{stream['name']}",
          description: "Environment Canada Station #{@id} #{stream['name']}",
          # TODO: Use mapping to improve unit of measurement
          unitOfMeasurement: {
            name:       stream['uom'],
            symbol:     '',
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

    # Save the Station metadata to the metadata cache file
    def save_metadata
      IO.write(@metadata_path, JSON.pretty_generate(@metadata))
    end
  end
end
