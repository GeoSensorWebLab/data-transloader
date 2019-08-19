module Transloader
  # Shared methods for multiple station classes
  module StationMethods
    # Use the observation_type to convert result to float, int, or 
    # string. This is used to use the most appropriate data type when
    # converting results to JSON.
    def coerce_result(result, observation_type)
      case observation_type
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement"
        result.to_f
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_CountObservation"
        result.to_i
      else # OM_Observation, any other type
        result
      end
    end

    # Determine the O&M observation type for the Datastream based on
    # the Observed Property (see Transloader::Ontology)
    def observation_type_for(property, ontology)
      ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
    end

    # Convert Last-Modified header String to Time object.
    def parse_last_modified(time)
      Time.httpdate(time)
    end

    # Convert a TOA5 timestamp String to a Time object.
    # An ISO8601 time zone offset (e.g. "-07:00") is required.
    def parse_toa5_timestamp(time, zone_offset)
      Time.strptime(time + "#{zone_offset}", "%F %T%z").utc
    end

    # Convert Time object to ISO8601 string with fractional seconds
    def to_iso8601(time)
      time.utc.strftime("%FT%T.%LZ")
    end

    # Convert an ISO8601 string to an ISO8601 string in UTC.
    # e.g. "2019-08-19T17:00:00.000-0600" to "2019-08-19T23:00:00.000Z"
    def to_utc_iso8601(iso8601)
      to_iso8601(Time.iso8601(iso8601))
    end
  end
end