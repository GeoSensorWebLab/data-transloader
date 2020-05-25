module Transloader
  # Class for abstracting away access to station metadata and
  # observations.
  # 
  # Sample Observation Hash:
  # * timestamp
  # * result
  # * property
  # * unit
  class DataStore
    # Create a new DataStore.
    def initialize(cache_path:, provider:, station:)
      raise MethodNotImplemented
    end

    # Retrieve all observations in the time interval
    def get_all_in_range(start_time, end_time)
      raise MethodNotImplemented
    end

    # Store observations (array)
    def store(observations)
      raise MethodNotImplemented
    end
  end
end