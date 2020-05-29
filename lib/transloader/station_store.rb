module Transloader
  # This class provides a single interface for storing and retrieving
  # metadata and data for a Station instance.
  class StationStore
    include SemanticLogger::Loggable

    # Create a new StationStore.
    # Must be initialized with a `provider` and `station` to scope
    # queries for data and metadata. The `database_url` will determine
    # the type of DataStore or MetadataStore used internally.
    def initialize(provider:, station:, database_url:)
      @provider       = provider
      @station_id     = station

      establish_connection(database_url)
      @data_store     = data_store_for_url(database_url)
      @metadata_store = metadata_store_for_url(database_url)
    end

    # Retrieve all Observations in the data store for the given
    # interval.
    # 
    # * `interval_start`: String with ISO8601 format
    # * `interval_end`: String with ISO8601 format
    # 
    # Dates must include a time zone offset (e.g. "-06:00").
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
        database_url: url,
        provider_key: @provider,
        station_key:  @station_id
      }

      case url
      when /^file:\/\//
        FileDataStore.new(store_opts)
      when /^postgres:\/\// 
        PostgresDataStore.new(store_opts)
      else
        raise Exception, "Invalid cache/database URL. Must start with 'file://'."
      end
    end

    # If `database_url` looks like a PostgreSQL connection URL, then
    # open a connection using ActiveRecord.
    def establish_connection(url)
      case url
      when /^postgres:\/\//
        logger.info "Opening connection to PostgreSQL"
        ActiveRecord::Base.establish_connection(url)
      end
    end

    # Select the correct MetadataStore sub-class based on the database
    # URL.
    # * `file://` will return an instance of FileMetadataStore
    def metadata_store_for_url(url)
      store_opts = {
        database_url: url,
        provider_key: @provider,
        station_key:  @station_id
      }

      case url
      when /^file:\/\//
        FileMetadataStore.new(store_opts)
      when /^postgres:\/\// 
        PostgresMetadataStore.new(store_opts)
      else
        raise Exception, "Invalid cache/database URL. Must start with 'file://'."
      end
    end
  end
end
