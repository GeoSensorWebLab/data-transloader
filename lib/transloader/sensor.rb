require 'json'
require 'uri'

module Transloader
  # Sensor entity class.
  class Sensor < Entity

    attr_accessor :description, :encoding_type, :metadata, :name

    def initialize(attributes)
      super(attributes)
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

    def upload_to(url)
      upload_url = URI(url + "Sensors")
      self.upload_to_path(upload_url)
    end
  end
end
