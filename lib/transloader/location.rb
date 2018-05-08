require 'json'
require 'uri'

require 'transloader/entity'

module Transloader
  # Location entity class.
  class Location < Entity

    attr_accessor :description, :encoding_type, :location, :name

    def initialize(attributes)
      super(attributes)
      @name = attributes[:name]
      @description = attributes[:description]
      @encoding_type = attributes[:encodingType]
      @location = attributes[:location]
    end

    def to_json
      JSON.generate({
        name: @name,
        description: @description,
        encodingType: @encoding_type,
        location: @location
      })
    end

    def upload_to(url)
      upload_url = self.join_uris(url, "Locations")
      self.upload_to_path(upload_url)
    end
  end
end
