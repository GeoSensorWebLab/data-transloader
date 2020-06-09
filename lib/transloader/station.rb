require_relative "../sensorthings/entity_factory"

module Transloader
  # Base template parent class for Station classes that are specific to
  # different data providers. Station sub-classes must provide the four
  # main interaction methods:
  #
  # 1. download_metadata
  # 2. upload_metadata
  # 3. download_observations
  # 4. upload_observations
  #
  # Provider-specific logic should be extracted to private methods, and
  # shared code can be extracted to the `StationMethods` module.
  #
  # By inheriting this class, sub-classes can call super() to have some
  # boilerplate automatically managed.
  class Station
    # All sub-classes should call `super(options)` to have these
    # instance variables auto-set.
    def initialize(options = {})
      @http_client    = options[:http_client]
      @id             = options[:id]
      @properties     = options[:properties]
      @metadata       = {}
      @entity_factory = SensorThings::EntityFactory.new(http_client: @http_client)
    end

    def download_metadata(override_metadata: {}, overwrite: false)
    end

    def upload_metadata(server_url, options = {})
    end

    def download_observations(interval = nil)
    end

    def upload_observations(destination, interval, options = {})
    end
  end
end