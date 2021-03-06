# Changelog for Data Transloader

## Version 0.8.0 (Unreleased)

* **Breaking Change**: The command line option `--cache` has been replaced with `--database_url`
* **Breaking Change**: Using a local file-based cache requires `file://` at the start of the path
* **Breaking Change**: Ruby 2.6 or newer is now required.
* **Breaking Change**: All "Provider" classes have been removed. "Station" classes should instead be created directly.

* PostgreSQL may be used as an alternative to a directory of JSON files for storing intermediary data
* Testing scripts have been added for different providers to test the tool with a local SensorThings API instance
* Add truncation feature for cassette cleaner (testing tool)
* Add option for multi-threading requests to PostgreSQL data store
* Multiple minor performance improvements to remove code that does not always need to run
* Removal of "Provider" classes to move all metadata-gathering methods into the Station classes, and to be fully compatible with the Postgres-based stores

## Version 0.7.0 (2020-05-22)

* Add warnings for empty ObservedProperty attributes in the Ontologies
* Follow redirects when stations list is moved to a new URL
* Add Travis CI configuration file
* Use "#select" instead of "#filter" for Ruby 2.4 compatibility
* Update to use HTTPS URLs (Environment Canada data sources now use HTTPS)
* Improve logging of STA interactions, which can be graphed by Munin
* Fix early exit bug that caused some entities to not be uploaded
* Add Docker deployment option
* Add timecop gem for rspec consistency
* Force update Data Garrison observations before downloading from their remote server
* Add sub-key editing of metadata from CLI
* Add instructions for working with historical KLRS weather data
* Add module for importing historical KLRS weather data files into STA
* Add instructions for working with historical KLRS energy usage data
* Add module for importing historical KLRS energy usage data files into STA
* Extract reusable creation of STA entities
* Simplify shared ontology lookup function
* Add TOA5 Document class for shared parsing code
* Extract shared time interval method

## Version 0.6.2 (2019-09-19)

* Improve error handling when SWOB-ML files are unavailable from Environment Canada
* Implement custom Error classes in SensorThings and Transloader modules
* Add tests for some Ontology methods
* Switch to error catching at high-level `transload` tool
* Add warnings for long attributes in SensorThings API entities
* Adjust descriptions in Ontology to be under 256 characters in length

## Version 0.6.1 (2019-09-05)

* Support customizable log level from environment variable `LOG_LEVEL` for `transload` tool
* Expand usage of debug and trace logging in Transloader library
* Change message for entity re-use to a debug log (from an info log)
* Fix bug in Data Garrison where linked data files with empty file names would cause a crash as they had no TSV to download
* Add `show metadata` command to `transload` tool
* Add `edit metadata` comamnd to `transload` tool
* **Remove** inclusion of `v2` from cache path; provider directories will now be added directly to the cache directory (as in v0.5.0)

## Version 0.6.0 (2019-08-28)

* Add support for HTTP Basic Access Authentication when downloading and uploading data/metadata
* Support custom HTTP headers being specified by API or by command-line tool
* Switch to using centralized class for managing station metadata (`MetadataStore`) instead of it being specific to each provider
* Also switch to similar class for station observations being centrally managed
* Use symbolized keys for hashes in more classes
* Change `:id` to `:name` for `DataGarrisonStation`
* Fix broken `data_urls` argument option in command-line interface
* Add Station façade class and simplify public interface to stations API
* Support downloading historical observations for Environment Canada (only past 1 month is available from provider)
* Fix typos in transload tool
* Rename `new_station` to `get_station` for Provider classes
* Add shared StationMethods module for sharing code between Station classes
* Add overwrite option for metadata (defaults to `false` or "off")
* Add schema versioning for stores to make future upgrades cleaner
* Fix bug where HTTP class would inherit request options from previous requests
* Fix wrong string for warning message on Campbell Scientific
* Enable datastream blocks in test automate script to mirror production usage
* Add tests for data and metadata stores, and remove similar code from station tests
* Add tests for data file parsing for Campbell Scientific
* Add tests for partial download support
* Extract partial download code to shared methods
* Add DataFile class for re-using data file partial downloading between providers
* Download data file metadata for Data Garrison when downloading metadata
* Use Data File partial downloads for Data Garrison instead of HTML parsing for observations
* Remove obsolete code in Campbell Scientific station class
* Avoid storing multiple duplicate datastreams for Campbell Scientific stations

## Version 0.5.0 (2019-07-26)

The "HTTP and Ontology" Refactoring Release

* Create HTTP wrapper to abstract away `net/http` from all the other classes
* Add Vagrantfile for starting a VM with FROST for testing
* Improve compatibility with HTTPS connections
* Add a User-Agent for the crawler
* Replace command line interface with better option parser-based command line interface
* Add validation checks for command line options
* Support uploading observations for a time interval instead of a single timestamp
* RENAME command line options to be closer to their usage in the station classes
* Use `time` instead of `date`/`datetime` in Ruby
* Add RDF Ontology file for clearly mapping observed properties from data providers to a standard vocabulary that can be re-used in SensorThings API
* Import known properties from the providers into the Ontology. Some properties that have not been downloaded in testing may be missing.
* Add Ontology mappings for Units of Measurement
* Add Ontology mappings for observation types
* Move provider-specific classes to subdirectories to clean up parent directory
* Add allow/block feature for controlling what data/metadata is uploaded to SensorThings API

## Version 0.4.0 (2019-07-12)

The "RSpec" Refactoring Release

* Clean up how station classes are instantiated with `get_station` and `new_station`
* Refactor the provider class interface to use `get` and `new` terms
* Improve usage of Ruby named keyword parameters for methods
* Add some documentation for metadata mapping procedure
* Fix broken Environment Canada integration due to new station list format (their change)
* Fix URL used for Data Garrison metadata to prevent bug where metadata was missed
* Add support for PUT requests to SensorThings API (usage only needed for some STA implementations)
* Fix wrong URL being cached due to body/header mismatch coming back from STA (GOST)
* Switch from testing with GOST to SensorUp Scratchpad for better STA support
* Use RSpec and VCR for integration testing station download/upload
* Standardize on symbolized keys in station classes to prevent bug where JSON deserialization would create string keys instead
* Add `semantic_logger` gem for improved logging output
* Switch from SensorUp Scratchpad to local FROST server for easier resets of testing data
* Issue another GET request for entity's true selfLink as some STA implementations (FROST) do not include a created entity in the response body
* Replace calls to `exit` with `raise` to not cause mysterious RSpec failures
* Fix for `$filter` usage where dates should not be quoted (FROST)
* Improve reliability of Campbell Scientific download/upload
* Standardize date format used for specifying uploads
* Change Campbell Scientific classes to only upload latest observation like the other providers instead of uploading all observations

## Version 0.3.0 (2019-03-07)

The "Campbell Scientific" Support Release

* Move the SensorThings API library to its own directory
* Support download for Campbell Scientific data
* Support downloading from specified CSV files for Campbell Scientific
* Automatically merge downloaded Campbell Scientific data into local cache
* Support HTTP partial downloads for Campbell Scientific CSV files
* Increase upload timeouts for long uploads to SensorThings API
* Support STA upload for Campbell Scientific
* Fix timezone storage in local cache files

## Version 0.2.0 (2019-02-28)

The "Data Garrison" Support Release

* Support download from Data Garrison data
* Add warnings for manual data correction requirement
* Support STA upload for Data Garrison

## Version 0.1.0 (2018-05-09)

The Initial "Environment Canada" Support Release

* Download Environment Canada weather data to cache files
* Create script to parse command line arguments
* Download Environment Canada station metadata to cache file
* Create sub-directories for data, metadata cache
* Create STA entities from metadata, upload to STA
* Re-use existing STA entities, if possible
* Build internal SensorThings API Ruby library
