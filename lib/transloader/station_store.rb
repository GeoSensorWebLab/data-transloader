module Transloader
  # This class provides a single interface for storing and retrieving
  # metadata and data for a Station instance.
  class StationStore
    # Create a new StationStore.
    # Must be initialized with a `provider` and `station` to scope
    # queries for data and metadata. The `database_url` will determine
    # the type of DataStore or MetadataStore used internally.
    def initialize(provider:, station:, database_url:)
      @provider       = provider
      @station_id     = station
      store_opts      = {
        cache_path: database_url,
        provider:   @provider,
        station:    @station_id
      }
      @data_store     = data_store_for_url(database_url)
      @metadata_store = metadata_store_for_url(database_url)
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

    private

    # Select the correct DataStore sub-class based on the database URL.
    # * `file://` will return an instance of FileDataStore
    def data_store_for_url(url)
      store_opts = {
        cache_path: url,
        provider:   @provider,
        station:    @station_id
      }

      case url
      when /^file:\/\//
        FileDataStore.new(store_opts)
      else
        raise Exception, "Invalid cache/database URL. Must start with 'file://'."
      end
    end

    # Select the correct MetadataStore sub-class based on the database
    # URL.
    # * `file://` will return an instance of FileMetadataStore
    def metadata_store_for_url(url)
      store_opts = {
        cache_path: url,
        provider:   @provider,
        station:    @station_id
      }

      case url
      when /^file:\/\//
        FileMetadataStore.new(store_opts)
      else
        raise Exception, "Invalid cache/database URL. Must start with 'file://'."
      end
    end
  end
end
