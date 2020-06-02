require "deep_merge"

require_relative "../metadata_store"

module Transloader
  # Class for storing station metadata in a PostgreSQL database.
  class PostgresMetadataStore < MetadataStore
    # Schema version for handling schema upgrades
    SCHEMA_VERSION = 3

    attr_reader :metadata

    # Create a new MetadataStore.
    # * database_url: Ignored as a connection is established by
    #                 StationStore.
    # * station_key:  unique key for this station
    # * provider_key: string for provider name, used to keep provider
    #                 metadata separate.
    def initialize(database_url:, provider_key:, station_key:)
      @station = ARModels::Station.find_or_create_by(
        station_key:  station_key,
        provider_key: provider_key
      )
      # The database stores the keys as strings, but this Ruby library
      # uses symbols to access the keys. A HashWithIndifferentAccess
      # lets these co-exist.
      @metadata = ActiveSupport::HashWithIndifferentAccess.new(@station.metadata || {})
    end

    # Retrieve a value for a given key from the metadata store.
    def get(key)
      @metadata.fetch(key, nil)
    end

    # Store a value for a given key in the metadata store.
    def set(key, value)
      @metadata.store(key, value)
      commit
    end

    # Merge multiple values in a hash into the metadata store.
    def merge(hash)
      @metadata.deep_merge!(hash)
      commit
    end

    private

    # Print a warning if the schema version doesn't match
    def check_schema(data)
      if data[:schema_version] != SCHEMA_VERSION
        logger.warn "Local metadata store schema version mismatch!"
      end
    end

    # Dump the current contents of the metadata hash to a file.
    def commit
      @station.update(metadata: @metadata)
    end
  end
end