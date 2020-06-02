require "transloader/ontology"

module Transloader
  # Convenience class that has the data provider pre-set.
  class DataGarrisonOntology < Ontology
    def initialize
      super(:DataGarrison)
    end
  end
end
