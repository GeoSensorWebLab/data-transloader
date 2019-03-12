# Mapping Source Data

These directories contain JSON files for mapping observed property and units from data providers to a standard set of of SensorThings API compatible entities.

For example, `TEMPERATURE_Avg` from Campbell Scientific and `Temperature` from Data Garrison represent the same Observed Property, so they should share the same Observed Property entity in SensorThings API.

## Future Work

It would be a good idea to extract these mappings to their own public Git repository, where additions could be made through pull requests. I would like to refine the encoding of the mappings and definitions before I do that.
