require 'json'
require 'uri'

require 'transloader/entity'

module Transloader
  # ObservedProperty entity class.
  class ObservedProperty < Entity

    attr_accessor :description, :definition, :name

    def initialize(attributes)
      super(attributes)
      @definition = attributes[:definition]
      @description = attributes[:description]
      @name = attributes[:name]
    end

    def to_json
      JSON.generate({
        definition: @definition,
        description: @description,
        name: @name
      })
    end

    def upload_to(url)
      upload_url = URI(url + "ObservedProperties")
      self.upload_to_path(upload_url)
    end
  end
end
