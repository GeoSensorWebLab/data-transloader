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
  class Station
    def initialize(options = {})
    end

    def download_metadata(override_metadata: {}, overwrite: false)
    end

    def upload_metadata(server_url, options = {})
    end

    def download_observations(interval = nil)
    end

    def upload_observations(destination, interval, options = {})
    end

    private

    # Cache an EntityFactory used to simplify creation of entities sent
    # to SensorThings API
    def entity_factory
      @entity_factory ||= SensorThings::EntityFactory.new(http_client: @http_client)
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      # TODO: Should this be a replacement instead of a merge?
      @store.merge_metadata(@metadata)
    end
  end
end
