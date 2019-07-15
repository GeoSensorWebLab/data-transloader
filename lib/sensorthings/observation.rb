require 'json'

require 'sensorthings/entity'

module SensorThings
  # Observation entity class.
  class Observation < Entity

    attr_accessor :phenomenon_time, :result, :result_time

    def initialize(attributes)
      super(attributes)
      @phenomenon_time = attributes[:phenomenonTime]
      @result = attributes[:result]
      @result_time = attributes[:resultTime]
    end

    def to_json
      JSON.generate({
        phenomenonTime: @phenomenon_time,
        result: @result,
        resultTime: @result_time
      })
    end

    # Check if self is a subset of entity.
    # Cycling through JSON makes the keys the same order and all stringified.
    def same_as?(entity)
      JSON.parse(self.to_json) == JSON.parse(JSON.generate({
        phenomenonTime: entity['phenomenonTime'],
        result: entity['result'],
        resultTime: entity['resultTime']
      }))
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Observations")

      filter = "phenomenonTime eq #{@phenomenon_time}"
      response = self.get(upload_url + "?$filter=#{filter}")
      body = JSON.parse(response.body)

      if response.code != "200"
        raise "Error: Could not GET entities. #{url}\n #{response.body}\n #{filter}"
      end

      # Look for matching existing entities. If no entities match, use POST to
      # create a new entity. If one or more entities match, then the first is
      # re-used. If the matching entity has the same phenomenonTime but
      # different other attributes, then a PATCH request is used to
      # synchronize.
      if body["value"].length == 0
        self.post_to_path(upload_url)
      else
        existing_entity = body["value"].first
        @link = existing_entity['@iot.selfLink']
        @id = existing_entity['@iot.id']

        if same_as?(existing_entity)
          logger.info "Re-using existing Observation entity."
        else
          self.patch_to_path(@link)
        end
      end
    end
  end
end
