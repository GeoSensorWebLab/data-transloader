require 'json'
require 'uri'

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

    def upload_to(url)
      upload_url = URI.join(url, "Things")
      self.upload_to_path(upload_url)
    end
  end
end
