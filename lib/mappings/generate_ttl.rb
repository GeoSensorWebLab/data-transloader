#!/usr/bin/env ruby
# Convert from JSON to RDF individuals.
require 'json'

if ARGV.count != 1
  $stderr.puts "USAGE: ruby generate_ttl.rb path/to/mapping.json"
  exit 1
end

path = ARGV[0]

mapping = JSON.parse(IO.read(path))
output = ""

def e(str)
  str.gsub('"', '\"')
end

def u(str)
  str.gsub(" ", "_")
end

# Generate ObservedProperty
op = mapping["ObservedProperty"]
output += <<-EOH
###  http://gswlab.ca/ontologies/etl-ontology#Property:#{u(op["name"])}
etl-ontology:Property:#{u(op["name"])} rdf:type owl:NamedIndividual ,
                                                  etl-ontology:ObservedProperty ;
                                         etl-ontology:definition "#{op["definition"]}"^^xsd:anyURI ;
                                         etl-ontology:description "#{e(op["description"])}"^^xsd:string .

EOH

# Generate UOM
uom = mapping["UnitOfMeasurement"]
output += <<-EOH
###  http://gswlab.ca/ontologies/etl-ontology#Unit:#{u(uom["name"])}
etl-ontology:Unit:#{u(uom["name"])} rdf:type owl:NamedIndividual ,
                                etl-ontology:UnitOfMeasurement ;
                       etl-ontology:definition "#{uom["definition"]}"^^xsd:anyURI ;
                       etl-ontology:name "#{uom["name"]}"^^xsd:string ;
                       etl-ontology:symbol "#{uom["symbol"]}"^^xsd:string .

EOH

# Generate SourceProperty
provider = case mapping["provider"]
when "data_garrison" then "DataGarrison"
when "environment_canada" then "EnvironmentCanada"
when "data_garrison" then "DataGarrison"
end

output += <<-EOH
###  http://gswlab.ca/ontologies/etl-ontology##{provider}:#{u(mapping["id"])}
etl-ontology:DataGarrison:#{u(mapping["id"])} rdf:type owl:NamedIndividual ,
                                              etl-ontology:SourceProperty ;
                                     etl-ontology:matchesObservedProperty etl-ontology:Property:#{u(op["name"])} ;
                                     etl-ontology:matchesUnitOfMeasurement etl-ontology:Unit:#{u(uom["name"])} .

EOH

puts output