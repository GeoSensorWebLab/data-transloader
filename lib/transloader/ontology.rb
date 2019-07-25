require "rdf/turtle"

module Transloader
  # Class for taking a source property from a data provider and 
  # returning normalized Observed Property, Unit of Measurement, and
  # Observation Type for SensorThings API.
  # 
  # The data is sourced from the RDF ontology embedded in this library.
  class Ontology
    ONTOLOGY_PATH = "../../ontologies/etl-ontology.ttl"

    # RDF Entity Definition Aliases
    DEFS = {
      definition:               RDF::URI("http://gswlab.ca/ontologies/etl-ontology#definition"),
      description:              RDF::URI("http://gswlab.ca/ontologies/etl-ontology#description"),
      matchesObservedProperty:  RDF::URI("http://gswlab.ca/ontologies/etl-ontology#matchesObservedProperty"),
      matchesUnitOfMeasurement: RDF::URI("http://gswlab.ca/ontologies/etl-ontology#matchesUnitOfMeasurement"),
      observationType:          RDF::URI("http://gswlab.ca/ontologies/etl-ontology#observationType"),
      symbol:                   RDF::URI("http://gswlab.ca/ontologies/etl-ontology#symbol")
    }

    # Create an Ontology instance.
    # 
    # * `provider`: The data provider as a CamelCased symbol
    def initialize(provider)
      @provider = provider.to_s
      @graph = RDF::Graph.load(File.absolute_path(File.join(__FILE__, ONTOLOGY_PATH)), format: :ttl)
    end

    def observation_type(property)
      solutions = get_uom_for(encode(property))

      if solutions.empty?
        nil
      elsif solutions.count == 1
        object_uri = solutions.first[:object]
        individual = reduce_solutions(get_all_by_subject(object_uri))
        individual[DEFS[:observationType]][0].humanize
      else
        # Only one should have been matched — probably an ontology issue
        raise "Too many matching units of measurement"
      end
    end

    # Return a Hash representing the canonical ObservedProperty for a 
    # given source property. If no matches are available, `nil` is 
    # returned.
    def observed_property(property)
      solutions = get_all_by_subject(RDF::URI(uri_for(encode(property))))
        .filter(predicate: DEFS[:matchesObservedProperty])

      if solutions.empty?
        nil
      elsif solutions.count == 1
        object_uri = solutions.first[:object]
        individual = reduce_solutions(get_all_by_subject(object_uri))
        {
          definition:  individual[DEFS[:definition]][0].humanize,
          description: individual[DEFS[:description]][0].humanize,
          name:        individual[RDF::RDFS.label][0].humanize
        }
      else
        # Only one should have been matched — probably an ontology issue
        raise "Too many matching observed properties"
      end
    end

    def unit_of_measurement(property)
      solutions = get_uom_for(encode(property))

      if solutions.empty?
        nil
      elsif solutions.count == 1
        object_uri = solutions.first[:object]
        individual = reduce_solutions(get_all_by_subject(object_uri))
        {
          definition:  individual[DEFS[:definition]][0].humanize,
          symbol:      individual[DEFS[:symbol]][0].humanize,
          name:        individual[RDF::RDFS.label][0].humanize
        }
      else
        # Only one should have been matched — probably an ontology issue
        raise "Too many matching units of measurement"
      end
    end

    private

    # Convert a string for compatibility with URLs.
    # Replaces spaces with underscores.
    def encode(string)
      string.gsub(" ", "_")
    end

    # Return a solution set for all items matching the given subject.
    def get_all_by_subject(subject)
      RDF::Query.execute(@graph) do
        pattern [subject, :predicate, :object]
      end
    end

    def get_uom_for(property)
      get_all_by_subject(RDF::URI(uri_for(property)))
        .filter(predicate: DEFS[:matchesUnitOfMeasurement])
    end

    # Reduce the solutions array to a Hash with predicates as keys, and
    # an array of objects as values.
    def reduce_solutions(solutions)
      solutions.reduce({}) do |memo, solution|
        memo[solution[:predicate]] ||= []
        memo[solution[:predicate]].push(solution[:object])
        memo
      end
    end

    def uri_for(property)
      "http://gswlab.ca/ontologies/etl-ontology##{@provider}:#{property}"
    end
  end
end