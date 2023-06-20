# Ontologies

The [RDF] ontology files in this directory provide semantic mappings for metadata from the data providers into a standard vocabulary of entities for SensorThings API.

Observed Properties from a provider are namespaced and matched to a single Unit of Measurement and Observed Property. A class in the Data Transloader Ruby library will provide an API for looking up these mappings.

[RDF]: https://en.wikipedia.org/wiki/Resource_Description_Framework

## Example

The source data provider `Data Garrison` provides observations for a sensor with the property `Pressure` and units `mbar`. This maps to the RDF Individual `DataGarrison:Pressure`. Properties are namespaced by their provider in case different providers use the same names.

The Individual `DataGarrison:Pressure` has Object Properties `matchesObservedProperty` and `matchesUnitOfMeasurement` (not part of any predefined vocabulary). `matchesObservedProperty` links to an RDF Individual for the Observed Property, and `matchesUnitOfMeasurement` links to an RDF Individual for the Unit of Measurement. Both of these Individuals are in this Ontology.

The Observed Property Individual matched is in the `Property` as `Air_Pressure`. This Individual can be referenced by properties from multiple data providers (or even the same data provider). It has data properties for the SensorThings API entity properties: `definition`, and `description`. An annotation of `rdfs:label` is used for `name`. It also MAY have an `skos:exactMatch` to link to an external ontology.

The Unit of Measurement Individual matched is in the `Unit` namespace as `Unit:Millibar`. Units may have different prefixes but refer to the same "Unit" — this currently isn't normalized in the ontology. It also has data properties to match the SensorThings API entity: `symbol`, `definition`. An annotation of `rdfs:label` is used for `name`. The data property for `observationType` can be applied to the Datastream, as the units can imply a certain type of observation content (e.g. URI, double, boolean, or anything).

## Re-using the Ontology

This ontology is provided as open data under a Creative Commons Attribution 4.0 International License.

## Editing the Ontology

The ontology is encoded in the [RDF Turtle format][Turtle]. I recommend using an editing application such as [Protégé][Protege] to avoid making typos or errors when editing the ontology. When pasting in new data to the TTL file, open the file in Protege and re-save it to reformat it.

Avoid using special characters for RDF Individual names, and try to use simple alpha-numeric characters instead to avoid parsing issues. For description and label strings, avoid exceeding 255 characters in length as this may conflict with some SensorThings API implementations.

If a `definition` for a `Property` is an empty string, this will cause an error in SensorThings API.

[Protege]: https://protege.stanford.edu
[Turtle]: https://en.wikipedia.org/wiki/Turtle_(syntax)

## Versioning

I intend to use [Semantic Versioning][semver] with the Ontology. Any changes to the Ontology that would require a change in code to use will require a major version bump.

[semver]: https://semver.org
