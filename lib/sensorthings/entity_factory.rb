module SensorThings
  # Class for generating Entities with certain attributes pre-filled,
  # such as HTTP client options.
  class EntityFactory
    include SemanticLogger::Loggable

    def initialize(options = {})
      @http_client = options[:http_client] || Transloader::HTTP.new
    end

    def new_thing(attributes)
      Thing.new(attributes, @http_client)
    end

    def new_location(attributes)
      Location.new(attributes, @http_client)
    end

    def new_sensor(attributes)
      Sensor.new(attributes, @http_client)
    end

    def new_observed_property(attributes)
      ObservedProperty.new(attributes, @http_client)
    end

    def new_datastream(attributes)
      Datastream.new(attributes, @http_client)
    end

    def new_observation(attributes)
      Observation.new(attributes, @http_client)
    end
    
  end
end
