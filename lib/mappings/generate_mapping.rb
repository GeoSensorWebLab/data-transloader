#!/usr/bin/env ruby
# Create a new mapping file skeleton based on command line input 
# parameters.
require 'json'


if ARGV.count != 3
  $stderr.puts "USAGE: ruby generate_mapping.rb \"source property name\" \"source units\" \"data provider\""
  exit 1
end

property_name, units, provider = ARGV

puts JSON.pretty_generate({
  id: property_name,
  DataProvider: provider,
  SourceUnits: units,
  UnitOfMeasurement: {
    name: "",
    symbol: "",
    definition: ""
  },
  ObservedProperty: {
    name: "",
    definition: "",
    description: ""
  }
})
