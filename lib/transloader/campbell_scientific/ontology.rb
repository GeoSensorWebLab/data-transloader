require "transloader/ontology"

module Transloader
  # Convenience class that has the data provider pre-set.
  class CampbellScientificOntology < Ontology
    def initialize
      super(:CampbellScientific)
    end
  end
end
