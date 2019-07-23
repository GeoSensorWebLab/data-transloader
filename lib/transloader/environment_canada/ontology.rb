require 'transloader/ontology'

module Transloader
  # Convenience class that has the data provider pre-set.
  class EnvironmentCanadaOntology < Ontology
    def initialize
      super(:EnvironmentCanada)
    end
  end
end
