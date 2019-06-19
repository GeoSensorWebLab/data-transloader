require 'json'
require 'uri'

require 'sensorthings/entity'

module SensorThings
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

    # Similar to `to_json` but does not include linked entities.
    def attributes_to_json
      JSON.generate({
        description: @description,
        name: @name,
        observationType: @observation_type,
        unitOfMeasurement: @unit_of_measurement
      })
    end

    # Check if self is a subset of entity.
    # Cycling through JSON makes the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.attributes_to_json) == JSON.parse(JSON.generate({
        description: entity['description'],
        name: entity['name'],
        observationType: entity['observationType'],
        unitOfMeasurement: entity['unitOfMeasurement']
      }))
    end

    # skip_matching_upload: if true, then don't re-use existing entities.
    # This is necessary for some STA implementations that do not support
    # deep merge.
    def upload_to(url, skip_matching_upload = false)
      upload_url = self.join_uris(url, "Datastreams")

      filter = "name eq '#{@name}' and description eq '#{@description}'"
      response = self.get(URI(upload_url + "?$filter=#{filter}"))
      body = JSON.parse(response.body)

      # Look for matching existing entities. If no entities match, use POST to
      # create a new entity. If one or more entities match, then the first is
      # re-used. If the matching entity has the same name/description but
      # different encodingType/metadata, then a PATCH request is used to
      # synchronize.
      if body["value"].length == 0 || skip_matching_upload
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link = existing_entity['@iot.selfLink']
        @id = existing_entity['@iot.id']

        if same_as?(existing_entity)
          puts "Re-using existing Datastream entity."
        else
          self.patch_to_path(URI(@link))
        end
      end
    end
  end
end
