require 'json'
require 'uri'

require 'transloader/entity'

module Transloader
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

    # Check if self is a subset of entity
    def same_as?(entity)
      entity['name'] == @name &&
      entity['description'] == @description &&
      entity['properties'] == @properties
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
      if body["@iot.count"] == 0
        self.post_to_path(upload_url)
      else
        existing_thing = body["value"].first
        @link = existing_thing['@iot.selfLink']
        @id = existing_thing['@iot.id']

        if same_as?(existing_thing)
          puts "Re-using existing entity."
        else
          self.patch_to_path(URI(@link))
        end
      end
    end
  end
end
