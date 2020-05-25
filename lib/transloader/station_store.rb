module Transloader
  # This class provides a single interface for storing and retrieving
  # metadata and data for a Station instance.
  class StationStore
    # Create a new StationStore.
    # Must be initialized with a `provider` and `station` to scope
    # queries for data and metadata. The `data_store` and
    # `metadata_store` are passed in to be able to share them with other
    # StationStore instances.
    def initialize(provider:, station:, data_store:, metadata_store:)
      @provider       = provider
      @station_id     = station
      @data_store     = data_store
      @metadata_store = metadata_store
    end

    # Retrieve all Observations in the data store for the given interval
    def get_data_in_range(interval_start, interval_end)
      @data_store.get_all_in_range(interval_start, interval_end)
    end

    # Merge a Hash of metadata into the metadata store's existing 
    # metadata
    def merge_metadata(metadata)
      @metadata_store.merge(metadata)
    end

    # Return a Hash containing the station's metadata
    def metadata
      @metadata_store.metadata
    end

    # Store a set of Observations in the data store
    def store_data(observations)
      @data_store.store(observations)
    end
  end
end
