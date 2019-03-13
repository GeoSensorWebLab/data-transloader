# Mapping Source Data

These directories contain JSON files for mapping observed property and units from data providers to a standard set of of SensorThings API compatible entities.

For example, `TEMPERATURE_Avg` from Campbell Scientific and `Temperature` from Data Garrison represent the same Observed Property, so they should share the same Observed Property entity in SensorThings API.

## Schema

The first-level directory defines the data provider, providing a scope for the source property name. Inside are JSON files named according to the source property name; for example, `TEMPERATURE_Avg` becomes `TEMPERATURE_Avg.json`. Source property names should be unique for each data provider<sup>[1](#uniqueness)</sup>.

Each JSON file has the following encoding:

```json
{
    "id": "TEMPERATURE_Avg",
    "DataProvider": "campbell_scientific",
    "SourceUnits": "Deg C",
    "UnitOfMeasurement": {
        "name": "Celsius",
        "symbol": "℃",
        "definition": "http://mmisw.org/ont/mmi/udunits2-common/_86385633"
    },
    "ObservedProperty": {
        "name": "Air Temperature",
        "definition": "http://mmisw.org/ont/cf/parameter/air_temperature",
        "description": "Air temperature is the bulk temperature of the air, not the surface (skin) temperature."
    }
}
```

#### `id`

The source property name from the data provider. MUST match the filename.

#### `DataProvider`

A short string identifying the data provider.

#### `SourceUnits`

The textual form of the units from the data provider.

#### `UnitOfMeasurement`

A JSON object that has the same properties as a `UnitOfMeasurement` from [OGC SensorThings API Part 1: Sensing][STA]. These are:

##### `name`

A descriptive name for the Unit of Measurement.

##### `symbol`

The textual form of the unit symbol. For special symbols, be sure to use UTF-8 encoding.

##### `definition`

A URI with a definition of the Unit of Measurement.


#### `ObservedProperty`

A JSON object that has the same properties as an `ObservedProperty` from [OGC SensorThings API Part 1: Sensing][STA]. These are:

##### `name`

A descriptive name for the Observed Property.

##### `definition`

A URI with a definition of the Observed Property.

##### `description`

A short, human-readable description of the Observed Property. Should be clear enough to differentiate from other Observed Properties that may have similar names.


[STA]: http://docs.opengeospatial.org/is/15-078r6/15-078r6.html

## Definition Ontologies

For units and properties I recommend using an ontology as the source, as that provides a common vocabulary. Here are some sample open-access ontologies that can be linked.

### Properties

* [Climate and Forecast (CF) Standard Names](http://mmisw.org/ont/cf/parameter)

### Units

* [udunits2-common](http://mmisw.org/ont/mmi/udunits2-common)
* [BioPortal Units of Measurement Ontology](https://bioportal.bioontology.org/ontologies/UO/?p=summary)

## Footnotes

<a name="uniqueness">1</a>: *Environment Canada has multiple sub-providers with the same source property name, but they appear to refer to the same observed property.*

## `generate_mapping.rb`

A small Ruby script to automate generating skeleton JSON files. Simple example:

```terminal
$ ruby generate_mapping.rb "BattV_Avg" "Volts" "campbell_scientific" > "campbell_scientific/BattV_Avg.json"
```

Or it can be automated from a CSV source or similar:

```terminal
$ ruby -r csv -e "CSV.read('../../docs/mappings/campbell_scientific.csv', headers: true).each {|row| %x[ruby generate_mapping.rb \"#{row[0]}\" \"#{row[1]}\" campbell_scientific > \"campbell_scientific/#{row[0]}.json\"] }"
```

## Future Work

It would be a good idea to extract these mappings to their own public Git repository, where additions could be made through pull requests. I would like to refine the encoding of the mappings and definitions before I do that.
