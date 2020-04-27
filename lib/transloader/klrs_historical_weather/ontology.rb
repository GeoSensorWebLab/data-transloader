require 'transloader/ontology'

module Transloader
  # Convenience class that has the data provider pre-set.
  class KLRSHistoricalWeatherOntology < Ontology
    def initialize
      super(:KLRSHistoricalWeather)
    end
  end
end
