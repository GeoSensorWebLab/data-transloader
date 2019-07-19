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

# Escape any double-quotes in the input string.
def e(str)
  str.gsub('"', '\"')
end

# Convert spaces to underscores in the input string.
def u(str)
  str.gsub(" ", "_")
end

# Generate ObservedProperty
op = mapping["ObservedProperty"]

# Only create entry if entity is defined. Entity may be undefined if
# an appropriate mapping cannot be found.
if op["name"] != ""
  output += <<-EOH
  ###  http://gswlab.ca/ontologies/etl-ontology#Property:#{u(op["name"])}
  etl-ontology:Property:#{u(op["name"])} rdf:type owl:NamedIndividual ,
                                                    etl-ontology:ObservedProperty ;
                                           etl-ontology:definition "#{op["definition"]}"^^xsd:anyURI ;
                                           etl-ontology:description "#{e(op["description"])}"^^xsd:string .

  EOH
end

# Generate UOM
uom = mapping["UnitOfMeasurement"]

# Only create entry if entity is defined. Entity may be undefined if
# an appropriate mapping cannot be found.
if uom["name"] != ""
output += <<-EOH
  ###  http://gswlab.ca/ontologies/etl-ontology#Unit:#{u(uom["name"])}
  etl-ontology:Unit:#{u(uom["name"])} rdf:type owl:NamedIndividual ,
                                  etl-ontology:UnitOfMeasurement ;
                         etl-ontology:definition "#{uom["definition"]}"^^xsd:anyURI ;
                         etl-ontology:name "#{uom["name"]}"^^xsd:string ;
                         etl-ontology:symbol "#{uom["symbol"]}"^^xsd:string .

  EOH
end

# Generate SourceProperty
provider = case mapping["DataProvider"]
when "data_garrison" then "DataGarrison"
when "environment_canada" then "EnvironmentCanada"
when "campbell_scientific" then "CampbellScientific"
else raise
end

# Check if destination entities are missing. If they are, then don't
# link to nothing.
if op["name"] != "" && uom["name"] != ""
  output += <<-EOH
  ###  http://gswlab.ca/ontologies/etl-ontology##{provider}:#{u(mapping["id"])}
  etl-ontology:#{provider}:#{u(mapping["id"])} rdf:type owl:NamedIndividual ,
                                                etl-ontology:SourceProperty ;
                                       etl-ontology:matchesObservedProperty etl-ontology:Property:#{u(op["name"])} ;
                                       etl-ontology:matchesUnitOfMeasurement etl-ontology:Unit:#{u(uom["name"])} .

  EOH
else
  output += <<-EOH
  ###  http://gswlab.ca/ontologies/etl-ontology##{provider}:#{u(mapping["id"])}
  etl-ontology:#{provider}:#{u(mapping["id"])} rdf:type owl:NamedIndividual ,
                                                etl-ontology:SourceProperty .

  EOH
end

puts output