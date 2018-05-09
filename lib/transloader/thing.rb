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


      if body["@iot.count"] == 0
        self.post_to_path(upload_url)
      else
        existing_thing = body["value"].first
        if !same_as?(existing_thing)
          # self.patch_to_path(thing, existing_thing)
        else
          puts "Re-using existing entity."
          @link = existing_thing['@iot.selfLink']
          @id = existing_thing['@iot.id']
        end
      end
    end
  end
end
