require "json"
require "transloader/data_store"

module Transloader
  # Store station metadata and observation data in a PostgreSQL
  # database.
  # 
  # Sample Observation Hash:
  # * timestamp
  # * result
  # * property
  # * unit
  class PostgresDataStore < DataStore
    # Schema version for handling schema upgrades
    SCHEMA_VERSION = 3

    # Create a new DataStore.
    # * database_url: Path to directory where metadata is stored
    # * station_key:  unique key for this station
    # * provider_key: string for provider name, used to keep provider 
    #                 metadata separate.
    def initialize(database_url:, provider_key:, station_key:)
      @database_url = database_url
      @provider_key = provider_key
      @station_key  = station_key
    end

    # Retrieve all observations in the time interval
    def get_all_in_range(start_time, end_time)
      day = start_time

      observations = []
      while (day <= end_time)
        cache = read_cache(day.strftime("%Y/%m/%d"))
        observations.concat(cache.values.select { |observation|
          t = Time.parse(observation[:timestamp])
          t >= start_time && t <= end_time
        })
        day += 86400
      end

      observations
    end

    # Store observations (array)
    def store(observations)
      # Group observation by day
      day_groups = observations.group_by do |observation|
        observation[:timestamp].strftime("%Y/%m/%d")
      end

      day_groups.each do |day, observations|
        # Open existing cache file
        existing = read_cache(day)
        
        # Merge in new values
        merged = observations.reduce(existing) do |memo, observation|
          key = "#{observation[:timestamp].to_s}-#{observation[:property]}"
          memo[key] = observation
          memo
        end

        # Store cache in file
        write_cache(day, merged)
      end
    end

    private

    # Print a warning if the schema version doesn't match
    def check_schema(data)
      if data[:schema_version] != SCHEMA_VERSION
        logger.warn "Local metadata store schema version mismatch!"
      end
    end

    # Return Hash of observations for a day ("%Y/%m/%d" format).
    # Key is "timestamp-property" to prevent duplicates.
    def read_cache(day)
      path = "#{@path}/#{day}.json"
      if File.exists?(path)
        data = JSON.parse(IO.read(path), symbolize_names: true)
        check_schema(data)
        data[:data]
      else
        {}
      end
    end

    # Write observations to cache file for a day ("%Y/%m/%d" format).
    # Observations should be a hash with keys of "timestamp-property"
    # for Observation hash values.
    def write_cache(day, observations)
      path = "#{@path}/#{day}.json"
      FileUtils.mkdir_p(File.dirname(path))
      IO.write(path, JSON.pretty_generate({
        data: observations,
        schema_version: SCHEMA_VERSION
      }))
    end
  end
end
