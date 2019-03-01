require 'json'
require 'uri'

require 'sensorthings/entity'

module SensorThings
  # Thing entity class.
  class Thing < Entity

    attr_accessor :description, :name, :properties

    def initialize(attributes)
      super(attributes)
      @name = attributes[:name]
      @description = attributes[:description]
      @properties = attributes[:properties]
    end

    def to_json
      JSON.generate({
        name: @name,
        description: @description,
        properties: @properties
      })
    end

    # Check if self is a subset of entity.
    # Cycling through JSON makes the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.to_json) == JSON.parse(JSON.generate({
        name: entity['name'],
        description: entity['description'],
        properties: entity['properties']
      }))
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Things")

      filter = "name eq '#{@name}' and description eq '#{@description}'"
      response = self.get(URI(upload_url + "?$filter=#{filter}"))
      body = JSON.parse(response.body)

      # Look for matching existing entities. If no entities match, use POST to
      # create a new entity. If one or more entities match, then the first is
      # re-used. If the matching entity has the same name/description but
      # different properties, then a PATCH request is used to synchronize.
      if body["value"].length == 0
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link = existing_entity['@iot.selfLink']
        @id = existing_entity['@iot.id']

        if same_as?(existing_entity)
          puts "Re-using existing Thing entity."
        else
          self.patch_to_path(URI(@link))
        end
      end
    end
  end
end
