# Documentation

Instructions on using the ETL for different data providers:

* [Campbell Scientific Weather Stations](CAMPBELL_SCIENTIFIC.md)
* [Data Garrison Weather Stations](DATA_GARRISON.md)
* [Environment Canada Weather Stations](ENVIRONMENT_CANADA.md)
* [Kluane Lake Research Station Historical Energy Usage Data](KLRS_HISTORICAL_ENERGY.md)
* [Kluane Lake Research Station Historical Weather Data](KLRS_HISTORICAL_WEATHER.md)

Additional customization of the ETL process:

* [Editing metadata values with a single command](editing_metadata.md)
* [Modifying the HTTP request/response for download/upload](http_customization.md)
* [Using a local directory for storing intermediary data](datastores/file_storage.md)
* [Alternatively using PostgreSQL for storing intermediary data](datastores/postgres_storage.md)

The inner workings of the ETL tool/library:

* [How Observed Properties from different sources are mapped to a common vocabulary](mappings.md)
* [A brief step-by-step guide for developing new modules](new_modules.md)


