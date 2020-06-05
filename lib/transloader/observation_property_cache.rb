module Transloader
  # Keep a cache of Observation property names mapped to Datastream
  # names. This is faster than doing a "#find" for the match for every
  # Observation; only an initial find to check the match is necessary.
  class ObservationPropertyCache
    # * datastream_names: A Set of unique names for the datastreams
    def initialize(datastream_names)
      @matches          = {}
      @datastream_names = datastream_names
    end

    # Check if an observation property name is in the cache, and store
    # it if it is missing. If it already exists, nothing is changed.
    def cache_observation_property(property_name)
      if !@matches.key?(property_name)
        matching_datastream = @datastream_names.find do |datastream|
          property_name.include?(datastream)
        end

        @matches[property_name] = matching_datastream
      end
    end

    # Returns true if the given observation property name maps to one
    # of the given datastream names. Returns false if none of the
    # datastream names have this observation's property. (False can
    # happen when datastream names have been changed.)
    def has_match?(property_name)
      !@matches[property_name].nil?
    end
  end
end
