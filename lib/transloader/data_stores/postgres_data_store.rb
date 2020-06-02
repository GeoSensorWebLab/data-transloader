require_relative "../data_store"

module Transloader
  # Store station metadata and observation data in a PostgreSQL
  # database.
  #
  # Sample Observation Hash:
  # * timestamp
  # * result
  # * property
  class PostgresDataStore < DataStore
    include SemanticLogger::Loggable

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

    # Retrieve all observations in the time interval.
    #
    # * `interval_start`: String with ISO8601 format
    # * `interval_end`: String with ISO8601 format
    #
    # Dates must include a time zone offset (e.g. "-06:00").
    def get_all_in_range(interval_start, interval_end)
      station = ARModels::Station.find_by(provider_key: @provider_key, station_key: @station_key)

      if station.nil?
        raise Exception, "Station not found by PostgresDataStore"
      end

      station.observations.where(
        "phenomenon_time >= :interval_start AND phenomenon_time <= :interval_end",
        {
          interval_start: interval_start,
          interval_end:   interval_end
        }
      ).map do |observation|
        {
          timestamp: observation.phenomenon_time.iso8601,
          result:    observation.result,
          property:  observation.property
        }
      end
    end

    # Store observations (array of hashes) in the database
    #
    # Observation Hash:
    # * timestamp
    # * result
    # * property
    def store(observations)
      station = ARModels::Station.find_by(provider_key: @provider_key, station_key: @station_key)

      db_observations = observations.map do |observation|
        {
          station_id:      station.id,
          phenomenon_time: observation[:timestamp],
          result:          observation[:result],
          property:        observation[:property]
        }
      end

      logger.info "Upserting #{db_observations.length} observations"

      # Slice observations into batches of at most 5000.
      db_observations.each_slice(5000) do |batch|
        # Use "upsert" to update existing observation records with new
        # results. Observation records are unique based on the
        # station_id, property name, and timestamp as SensorThings API
        # should not have multiple Observation entities with the same
        # phenomenonTime (when scoped to the same Datastream entity).
        station.observations.upsert_all(batch,
          unique_by: %i[station_id property phenomenon_time],
          returning: false)
      end
    end
  end
end
