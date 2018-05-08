require 'csv'
require 'fileutils'
require 'json'
require 'net/http'
require 'nokogiri'
require 'uri'

module Transloader
  class EnvironmentCanadaProvider
    CACHE_DIRECTORY = "environment_canada"
    METADATA_URL = "http://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"
    NAMESPACES = {
      'gml' => 'http://www.opengis.net/gml',
      'om' => 'http://www.opengis.net/om/1.0',
      'po' => 'http://dms.ec.gc.ca/schema/point-observation/2.0',
      'xlink' => 'http://www.w3.org/1999/xlink'
    }
    OBSERVATIONS_URL = "http://dd.weather.gc.ca/observations/swob-ml/latest/"

    def initialize(cache_path)
      @cache_path = cache_path

      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}")
      FileUtils.mkdir_p("#{@cache_path}/#{CACHE_DIRECTORY}/metadata")
      @station_list_path = "#{@cache_path}/#{CACHE_DIRECTORY}/stations_list.csv"
    end

    # Download the station list from Environment Canada and return the body string
    def download_station_list
      response = Net::HTTP.get_response(URI(METADATA_URL))

      raise "Error downloading station list" if response.code != '200'

      # Data is encoded as ISO-8859-1 but has no encoding headers, so encoding
      # must be manually applied. I then convert to UTF-8 for re-use later.
      body = response.body.force_encoding(Encoding::ISO_8859_1)
      body = body.encode(Encoding::UTF_8)
    end

    # Some station metadata is contained in the SWOB-ML files, such as the
    # sensor/observed property details.
    def download_station_metadata(station, type)
      swobml_url = URI.join(OBSERVATIONS_URL, "C#{station}-#{type}-swob.xml")
      response = Net::HTTP.get_response(swobml_url)

      raise "Error downloading station list" if response.code != '200'

      Nokogiri::XML(response.body)
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_station_metadata(station)
      metadata_path = "#{@cache_path}/#{CACHE_DIRECTORY}/metadata/#{station}.json"
      if File.exist?(metadata_path)
        metadata = JSON.parse(IO.read(metadata_path))
      else
        metadata = load_station_metadata(station)
        save_station_metadata(station, metadata)
      end
    end

    # Download list of stations from Environment Canada. If cache file exists,
    # re-use that instead.
    def get_stations_list
      if File.exist?(@station_list_path)
        body = IO.read(@station_list_path)
      else
        body = download_station_list
        save_station_list(body)
      end

      CSV.parse(body, headers: :first_row)
    end

    # Load the stations list and parse the desired station metadata
    def load_station_metadata(station)
      stations = get_stations_list

      station_row = stations.detect do |row|
        row["#IATA"] == station
      end

      raise "Station not found in list" if station_row.nil?

      case station_row['AUTO/MAN']
      when "Auto", "Manned/Auto"
        type = "AUTO"
      when "Manned"
        type = "MAN"
      else
        raise "Error: unknown station type"
      end
      xml = download_station_metadata(station, type)

      # Extract results from XML, use to build metadata needed for Sensor/
      # Observed Property/Datastream
      datastreams = xml.xpath('//om:result/po:elements/po:element', NAMESPACES).collect do |node|
        {
          name: node.xpath('@name').text,
          uom: node.xpath('@uom').text
        }
      end

      # Convert to Hash
      {
        name: "Environment Canada Station #{station_row["#IATA"]}",
        description: "Environment Canada Weather Station #{station_row["EN name"]}",
        elevation: xml.xpath('//po:element[@name="stn_elev"]', NAMESPACES).first.attribute('value').value,
        updated_at: Time.now,
        datastreams: datastreams,
        procedure: xml.xpath('//om:procedure/@xlink:href', NAMESPACES).text,
        properties: station_row.to_hash
      }
    end

    # Create and upload SensorThings API entities for `station` id to the server
    # at `destination`. Metadata for the station is read from the station
    # metadata cache files.
    def put_station_metadata(station, destination)
      # Get station metadata
      metadata = get_station_metadata(station)

      # THING entity
      # Create Thing entity
      thing_json = JSON.generate({
        name: metadata["name"],
        description: metadata["description"],
        properties: metadata["properties"]
      })

      # Upload entity and parse response
      things_url = URI.join(destination, "Things")
      thing_link = upload_entity(thing_json, things_url)["Location"]

      # Cache URL
      metadata['Thing@iot.navigationLink'] = thing_link
      save_station_metadata(station, metadata)

      # LOCATION entity
      # Create Location entity
      location_json = JSON.generate({
        name: metadata["name"],
        description: metadata["description"],
        encodingType: "application/vnd.geo+json",
        location: {
          type: "Point",
          coordinates: [metadata["properties"]["Longitude"].to_f, metadata["properties"]["Latitude"].to_f]
        }
      })

      # Upload entity and parse response
      locations_url = URI(thing_link + "/Locations")
      location_link = upload_entity(location_json, locations_url)["Location"]

      # Cache URL
      metadata['Location@iot.navigationLink'] = location_link
      save_station_metadata(station, metadata)

      # SENSOR entities
      sensors_url = URI.join(destination, "Sensors")
      metadata['datastreams'].each do |stream|
        # Create Sensor entities
        sensor_json = JSON.generate({
          name: "Station #{station} #{stream['name']} Sensor",
          description: "Environment Canada Station #{station} #{stream['name']} Sensor",
          # This encoding type is a lie, because there are only two types in
          # the spec and none apply here. Implementations are strict about those
          # two types, so we have to pretend.
          # More discussion on specification that could change this:
          # https://github.com/opengeospatial/sensorthings/issues/39
          encodingType: 'application/pdf',
          metadata: metadata['procedure']
        })

        # Upload entity and parse response
        sensor_response = upload_entity(sensor_json, sensors_url)

        # Cache URL and ID
        stream['Sensor@iot.navigationLink'] = sensor_response["Location"]
        stream['Sensor@iot.id'] = JSON.parse(sensor_response.body)["@iot.id"]
      end

      save_station_metadata(station, metadata)

      # OBSERVED PROPERTY entities
      observed_properties_url = URI.join(destination, "ObservedProperties")
      metadata['datastreams'].each do |stream|
        # Create Observed Property entities
        # TODO: Use mapping to improve these entities
        observed_property_json = JSON.generate({
          name: stream['name'],
          definition: "http://example.org/#{stream['name']}",
          description: stream['name']
        })

        # Upload entity and parse response
        observed_property_response = upload_entity(observed_property_json, observed_properties_url)

        # Cache URL
        stream['ObservedProperty@iot.navigationLink'] = observed_property_response['Location']
        stream['ObservedProperty@iot.id'] = JSON.parse(observed_property_response.body)['@iot.id']
      end

      save_station_metadata(station, metadata)

      # DATASTREAM entities
      datastreams_url = URI(thing_link + "/Datastreams")
      metadata['datastreams'].each do |stream|
        # Create Datastream entities
        # TODO: Use mapping to improve these entities
        datastream_json = JSON.generate({
          name: "Station #{station} #{stream['name']}",
          description: "Environment Canada Station #{station} #{stream['name']}",
          # TODO: Use mapping to improve unit of measurement
          unitOfMeasurement: {
            name: stream['uom'],
            symbol: '',
            definition: ''
          },
          # TODO: Use more specific observation types, if possible
          observationType: 'http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation',
          Sensor: {
            "@iot.id" => stream['Sensor@iot.id']
          },
          ObservedProperty: {
            "@iot.id" => stream['ObservedProperty@iot.id']
          }
        })

        # Upload entity and parse response
        datastream_response = upload_entity(datastream_json, datastreams_url)

        # Cache URL
        stream['Datastream@iot.navigationLink'] = datastream_response["Location"]
        stream['Datastream@iot.id'] = JSON.parse(datastream_response.body)['@iot.id']
      end

      save_station_metadata(station, metadata)
    end

    # Upload JSON string of entity to upload_url and return the response
    # Raises if upload failed.
    def upload_entity(entity, upload_url)
      request = Net::HTTP::Post.new(upload_url)
      request.body = entity
      request.content_type = 'application/json'

      response = Net::HTTP.start(upload_url.hostname, upload_url.port) do |http|
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      if response.class != Net::HTTPCreated
        raise "Error: Could not upload entity. #{upload_url}\n #{response.body}\n #{request.body}"
        exit 2
      end

      response
    end

    # Cache the raw body data to a file for re-use
    def save_station_list(body)
      IO.write(@station_list_path, body, 0)
    end

    def save_station_metadata(id, metadata)
      metadata_path = "#{@cache_path}/#{CACHE_DIRECTORY}/metadata/#{id}.json"
      IO.write(metadata_path, JSON.pretty_generate(metadata))
    end
  end
end
