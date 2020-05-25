module Transloader
  # Class for abstracting away storage for station metadata.
  class MetadataStore

    attr_reader :metadata

    # Create a new MetadataStore.
    # * cache_path: Path to directory where metadata is stored
    # * station:    unique key for this station
    # * provider:   string for provider name, used to keep provider 
    #               metadata separate.
    def initialize(cache_path:, provider:, station:)
      raise MethodNotImplemented
    end

    # Retrieve a value for a given key from the metadata store.
    def get(key)
      raise MethodNotImplemented
    end

    # Store a value for a given key in the metadata store.
    def set(key, value)
      raise MethodNotImplemented
    end

    # Merge multiple values in a hash into the metadata store.
    def merge(hash)
      raise MethodNotImplemented
    end
  end
end