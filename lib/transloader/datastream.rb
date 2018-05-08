require 'json'
require 'uri'

require 'transloader/entity'

module Transloader
  # Datastream entity class.
  class Datastream < Entity

    attr_accessor :description, :name, :observation_type, :observed_property,
                  :sensor, :unit_of_measurement

    def initialize(attributes)
      super(attributes)
      @description = attributes[:description]
      @name = attributes[:name]
      @observation_type = attributes[:observationType]
      @observed_property = attributes[:ObservedProperty]
      @sensor = attributes[:Sensor]
      @unit_of_measurement = attributes[:unitOfMeasurement]
    end

    def to_json
      JSON.generate({
        description: @description,
        name: @name,
        observationType: @observation_type,
        ObservedProperty: @observed_property,
        Sensor: @sensor,
        unitOfMeasurement: @unit_of_measurement
      })
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Datastreams")
      self.upload_to_path(upload_url)
    end
  end
end
