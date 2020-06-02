require "transloader/ontology"

module Transloader
  # Convenience class that has the data provider pre-set.
  class KLRSHistoricalEnergyOntology < Ontology
    def initialize
      super(:KLRSHistoricalEnergy)
    end
  end
end
