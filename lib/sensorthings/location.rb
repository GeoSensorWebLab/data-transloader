require "json"

require_relative "entity"

module SensorThings
  # Location entity class.
  class Location < Entity

    attr_accessor :description, :encoding_type, :location, :name

    def initialize(attributes, http_client)
      super(attributes, http_client)
      @name          = attributes[:name]
      @description   = attributes[:description]
      @encoding_type = attributes[:encodingType]
      @location      = attributes[:location]
    end

    def to_json
      JSON.generate({
        name:         @name,
        description:  @description,
        encodingType: @encoding_type,
        location:     @location
      })
    end

    # Check if self is a subset of entity.
    # Cycling through JSON makes the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.to_json) == JSON.parse(JSON.generate({
        name:         entity["name"],
        description:  entity["description"],
        encodingType: entity["encodingType"],
        location:     entity["location"]
      }))
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Locations")
      check_url = self.build_url(upload_url, {
        "$filter" => "name eq '#{@name}' and description eq '#{@description}'"
      })
      response   = self.get(check_url)
      body       = JSON.parse(response.body)

      # Look for matching existing entities. If no entities match, use
      # POST to create a new entity. If one or more entities match
      # **exactly**, then the first result is re-used. If entities match
      # name/description but not the location or encoding type, then a
      # POST is used to create a new Location.
      if body["value"].length == 0
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link           = existing_entity["@iot.selfLink"]
        @id             = existing_entity["@iot.id"]

        if same_as?(existing_entity)
          logger.debug "Re-using existing Location entity."
        else
          self.post_to_path(upload_url)
        end
      end
    end
  end
end
