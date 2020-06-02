require "json"

require "sensorthings/entity"

module SensorThings
  # ObservedProperty entity class.
  class ObservedProperty < Entity

    attr_accessor :description, :definition, :name

    def initialize(attributes, http_client)
      super(attributes, http_client)
      @definition  = attributes[:definition]
      @description = attributes[:description]
      @name        = attributes[:name]

      [:definition, :description, :name].each do |attr|
        if attributes[attr].nil? || attributes[attr].empty?
          logger.warn %Q[Warning: "#{attr}" attribute for Observed Property is nil or empty. This may cause an error in SensorThings API.]
        end
      end
    end

    def to_json
      JSON.generate({
        definition:  @definition,
        description: @description,
        name:        @name
      })
    end

    # Check if self is a subset of entity. Cycling through JSON makes
    # the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.to_json) == JSON.parse(JSON.generate({
        name:        entity["name"],
        description: entity["description"],
        definition:  entity["definition"]
      }))
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "ObservedProperties")
      check_url = self.build_url(upload_url, {
        "$filter" => "name eq '#{@name}'"
      })
      response   = self.get(check_url)
      body       = JSON.parse(response.body)

      # Look for matching existing entities. If no entities match, use
      # POST to create a new entity. If one or more entities match, then
      # the first is re-used. If the matching entity has the same
      # name/description but different encodingType/metadata, then a
      # PATCH request is used to synchronize.
      if body["value"].length == 0
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link           = existing_entity["@iot.selfLink"]
        @id             = existing_entity["@iot.id"]

        if same_as?(existing_entity)
          logger.debug "Re-using existing ObservedProperty entity."
        else
          self.patch_to_path(@link)
        end
      end
    end
  end
end
