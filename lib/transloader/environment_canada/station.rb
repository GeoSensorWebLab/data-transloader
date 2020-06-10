require "nokogiri"
require "time"

require_relative "../station"
require_relative "../station_methods"

module Transloader
  # Class for downloading and uploading metadata and observation data
  # from Environment Canada Data Mart. The data is downloaded over HTTP,
  # and uses the Surface Weather Observation XML encoding.
  class EnvironmentCanadaStation < Station
    include SemanticLogger::Loggable
    include Transloader::StationMethods

    LONG_NAME     = "Environment Canada Weather Station"
    METADATA_URL  = "https://dd.weather.gc.ca/observations/doc/swob-xml_station_list.csv"
    NAME          = "Environment Canada Station"
    PROVIDER_ID   = "EnvironmentCanada"
    PROVIDER_NAME = "environment_canada"

    NAMESPACES = {
      'gml'   => 'http://www.opengis.net/gml',
      'om'    => 'http://www.opengis.net/om/1.0',
      'po'    => 'http://dms.ec.gc.ca/schema/point-observation/2.0',
      'xlink' => 'http://www.w3.org/1999/xlink'
    }
    OBSERVATIONS_URL = "https://dd.weather.gc.ca/observations/swob-ml"

    attr_accessor :id, :metadata, :properties

    def initialize(options = {})
      @http_client           = options[:http_client]
      @id                    = options[:id]
      @store                 = StationStore.new({
        provider:     PROVIDER_NAME,
        station:      @id,
        database_url: options[:database_url]
      })

      @metadata = @store.metadata
      # TODO: These checks can be removed when the arguments are
      # changed to keywords
      @metadata[:properties] ||= {}
      properties = options[:properties] || {}
      @metadata[:properties].merge!(properties)
      @metadata[:properties][:provider] = "Environment Canada"
    end

    # Parse metadata from the Provider properties and the SWOB-ML file for a
    # metadata hash.
    # If `override_metadata` is specified, it is merged on top of the
    # downloaded metadata before being cached.
    def download_metadata(override_metadata: {})
      # Download additional station metadata from a CSV file. This
      # contains information used to generate the URL for the main
      # SWOB-ML data file.
      stations_list_metadata = get_station_row(@id)
      properties = @metadata[:properties].merge!(stations_list_metadata.to_hash)

      xml = get_observation_xml()

      # Extract results from XML, use to build metadata needed for Sensor/
      # Observed Property/Datastream
      datastreams = xml.xpath('//om:result/po:elements/po:element', NAMESPACES).collect do |node|
        {
          name: node.xpath('@name').text,
          uom:  node.xpath('@uom').text
        }
      end

      # Convert to Hash
      @metadata.merge!({
        name:        "#{NAME} #{@id}",
        description: "#{LONG_NAME} #{properties["Name"]}",
        elevation:   xml.xpath('//po:element[@name="stn_elev"]', NAMESPACES).first.attribute('value').value,
        updated_at:  Time.now,
        datastreams: datastreams,
        procedure:   xml.xpath('//om:procedure/@xlink:href', NAMESPACES).text,
        properties:  properties
      })

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
      # Filter Datastreams based on allowed/blocked lists.
      # If both are blank, no filtering will be applied.
      datastreams = filter_datastreams(@metadata[:datastreams], options[:allowed], options[:blocked])

      # THING entity
      # Create Thing entity
      thing = build_thing(@metadata[:properties])

      # Upload entity and parse response
      thing.upload_to(server_url)

      # Cache URL
      @metadata[:'Thing@iot.navigationLink'] = thing.link
      save_metadata

      # LOCATION entity
      # Create Location entity
      location = build_location()

      # Upload entity and parse response
      location.upload_to(thing.link)

      # Cache URL
      @metadata[:'Location@iot.navigationLink'] = location.link
      save_metadata

      # SENSOR entities
      datastreams.each do |stream|
        # Create Sensor entities
        sensor = build_sensor("Station #{@id} #{stream[:name]} Sensor", "#{NAME} #{@id} #{stream[:name]} Sensor")

        # Upload entity and parse response
        sensor.upload_to(server_url)

        # Cache URL and ID
        stream[:'Sensor@iot.navigationLink'] = sensor.link
        stream[:'Sensor@iot.id'] = sensor.id
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
        stream[:'ObservedProperty@iot.navigationLink'] = observed_property.link
        stream[:'ObservedProperty@iot.id'] = observed_property.id
      end

      save_metadata

      # DATASTREAM entities
      datastreams.each do |stream|
        datastream_name  = stream[:name]

        datastream = entity_factory.new_datastream({
          name:              "Station #{@id} #{datastream_name}",
          description:       "#{NAME} #{@id} #{datastream_name}",
          unitOfMeasurement: uom_for_datastream(datastream_name, stream[:uom]),
          observationType:   observation_type_for(datastream_name),
          Sensor:            {
            '@iot.id' => stream[:'Sensor@iot.id']
          },
          ObservedProperty:  {
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
    def download_observations(interval = nil)
      xml = get_observation_xml(interval)

      if xml.nil?
        raise Error, "Unable to download SWOB-ML"
      end

      # Parse date from SWOB-ML
      timestamp = Time.parse(xml.xpath('//po:identification-elements/po:element[@name="date_tm"]/@value', NAMESPACES).text)

      # New data store
      observations = xml.xpath("//om:result/po:elements/po:element", NAMESPACES).collect do |element|
        {
          timestamp: timestamp,
          result: element.at_xpath("@value", NAMESPACES).text,
          property: element.at_xpath("@name", NAMESPACES).text
        }
      end

      logger.info "Downloaded Observations: #{observations.length}"
      @store.store_data(observations)
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
      time_interval = Transloader::TimeInterval.new(interval)
      observations  = @store.get_data_in_range(time_interval.start, time_interval.end)
      logger.info "Uploading Observations: #{observations.length}"
      upload_observations_array(observations, options)
    end




    private

    # Download the station list from Environment Canada and return the
    # body string
    def download_station_list
      response = @http_client.get(uri: METADATA_URL)

      if response.code != "200"
        raise HTTPError.new(response, "Error downloading station list from Environment Canada")
      end

      # Data is encoded as ISO-8859-1 but has no encoding headers, so
      # encoding must be manually applied. I then convert to UTF-8 for
      # re-use later.
      body = response.body.force_encoding(Encoding::ISO_8859_1)
      body.encode(Encoding::UTF_8)
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
        # TODO: Determine if SWOB-ML is available for day
        logger.warn "Interval download not yet implemented for Environment Canada data"
      end
    end

    # Download the hourly SWOB-ML file in the `url` directory.
    # "AUTO" or "MANNED" will be determined automatically from the
    # station metadata.
    def get_swob_data_from_url(url)
      case @metadata["properties"]["AUTO/MAN"]
      when "AUTO", "Auto", "Manned/Auto"
        type = "AUTO"
      when "MAN", "Manned"
        type = "MAN"
      else
        raise Error, "Error: unknown station type"
      end

      swobml_url = "#{url}/#{@id}-#{type}-swob.xml"
      response = @http_client.get(uri: swobml_url)

      if response.code == "404"
        raise HTTPError.new(response, "SWOB-ML file not found for station #{@id}; data may be unavailable for the specified interval.")
      elsif response.code == "301"
        # Follow redirects
        response = @http_client.get(uri: response["Location"])
      elsif response.code != "200"
        raise HTTPError.new(response, "Error downloading station observation data")
      end

      response.body
    end

    def get_station_row(station_id)
      body = download_station_list()
      parsed_stations = CSV.parse(body, headers: :first_row)
      validate_stations(parsed_stations)
      station_row = parsed_stations.detect { |row| row["IATA_ID"] == station_id }
      if station_row.nil?
        raise Error, "Station \"#{station_id}\" not found in list"
      end
      station_row
    end

    # Validate the format of the stations.
    # If they have changed, then the code will probably fail to update
    # and a warning should be emitted.
    def validate_stations(stations)
      if stations.headers.join(",") != "IATA_ID,Name,WMO_ID,MSC_ID,Latitude,Longitude,Elevation(m),Data_Provider,Dataset/Network,AUTO/MAN,Province/Territory"
        logger.warn "Environment Canada stations source file headers have changed. Parsing may fail."
      end
    end
  end
end
