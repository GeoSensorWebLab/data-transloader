module Transloader
  # Shared methods for multiple station classes
  module StationMethods
    # Determine the O&M observation type for the Datastream based on
    # the Observed Property (see Transloader::Ontology)
    def observation_type_for(property, ontology)
      ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
    end
  end
end