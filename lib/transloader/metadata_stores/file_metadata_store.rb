require "deep_merge"
require "fileutils"
require "json"
require "transloader/metadata_store"

module Transloader
  # Class for abstracting away filesystem storage for station metadata.
  class FileMetadataStore < MetadataStore
    # Schema version for handling schema upgrades
    SCHEMA_VERSION = 2

    attr_reader :metadata

    # Create a new MetadataStore.
    # * cache_path: Path to directory where metadata is stored
    # * station:    unique key for this station
    # * provider:   string for provider name, used to keep provider 
    #               metadata separate.
    def initialize(cache_path:, provider:, station:)
      # Cut "file://" from beginning of URL
      @cache_path = cache_path.delete_prefix("file://")
      @provider   = provider
      @station    = station
      @path       = "#{@cache_path}/#{@provider}/metadata/#{@station}.json"
      @metadata   = read()
      FileUtils.mkdir_p("#{@cache_path}/#{@provider}/metadata")
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
      IO.write(@path, JSON.pretty_generate({
        metadata: @metadata,
        schema_version: SCHEMA_VERSION
      }))
    end

    def read
      if (File.exists?(@path))
        data = JSON.parse(IO.read(@path), symbolize_names: true)
        check_schema(data)
        data[:metadata]
      else
        {}
      end
    end
  end
end