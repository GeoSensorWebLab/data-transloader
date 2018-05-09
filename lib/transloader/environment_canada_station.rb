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
    end

    def observation_xml
      @xml ||= Nokogiri::XML(get_observations())
    end

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

    def save
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
      attributes = {
        name: "Environment Canada Station #{@id}",
        description: "Environment Canada Weather Station #{@properties["EN name"]}",
        elevation: xml.xpath('//po:element[@name="stn_elev"]', NAMESPACES).first.attribute('value').value,
        updated_at: Time.now,
        datastreams: datastreams,
        procedure: xml.xpath('//om:procedure/@xlink:href', NAMESPACES).text,
        properties: @properties
      }

      metadata_path = "#{@provider.cache_path}/#{EnvironmentCanadaProvider::CACHE_DIRECTORY}/metadata/#{@id}.json"
      IO.write(metadata_path, JSON.pretty_generate(attributes))
    end
  end
end
