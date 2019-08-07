require 'json'

require 'sensorthings/entity'

module SensorThings
  # Sensor entity class.
  class Sensor < Entity

    attr_accessor :description, :encoding_type, :metadata, :name

    def initialize(attributes, http_client)
      super(attributes, http_client)
      @name = attributes[:name]
      @description = attributes[:description]
      @encoding_type = attributes[:encodingType]
      @metadata = attributes[:metadata]
    end

    def to_json
      JSON.generate({
        name: @name,
        description: @description,
        encodingType: @encoding_type,
        metadata: @metadata
      })
    end

    # Check if self is a subset of entity.
    # Cycling through JSON makes the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.to_json) == JSON.parse(JSON.generate({
        name: entity['name'],
        description: entity['description'],
        encodingType: entity['encodingType'],
        metadata: entity['metadata']
      }))
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Sensors")

      filter = "name eq '#{@name}' and description eq '#{@description}'"
      response = self.get(upload_url + "?$filter=#{filter}")
      body = JSON.parse(response.body)

      # Look for matching existing entities. If no entities match, use POST to
      # create a new entity. If one or more entities match, then the first is
      # re-used. If the matching entity has the same name/description but
      # different encodingType/metadata, then a PATCH request is used to
      # synchronize.
      if body["value"].length == 0
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link = existing_entity['@iot.selfLink']
        @id = existing_entity['@iot.id']

        if same_as?(existing_entity)
          logger.info "Re-using existing Sensor entity."
        else
          self.patch_to_path(@link)
        end
      end
    end
  end
end
