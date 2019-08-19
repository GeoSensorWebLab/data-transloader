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
  end
end