# Arctic Sensor Web Data Transloader

This tool downloads weather station data from multiple sources and uploads it to an [OGC SensorThings API][] service. This makes the data available using an open and interoperable API.

[OGC SensorThings API]: http://docs.opengeospatial.org/is/15-078r6/15-078r6.html

## Setup Instructions

This tool requires [Ruby][] 2.4 or newer. Once Ruby is installed, you will need to install [Bundler][] to install the library dependencies.

```
$ cd data-transloader
$ gem install bundler
$ bundle install
```

This tool should be runnable on Linux, MacOS, and Windows.

[Bundler]: http://bundler.io
[Ruby]: https://www.ruby-lang.org/en/

## Usage

This tool is meant to be scriptable using [cron][], a scheduling daemon, to automate imports on a schedule. This is done by passing in command line arguments to the tool that handle the sensor metadata and observation download/upload.

Currently supported weather station sources:

* [Environment Canada][MSC]

Weather station sources with planned support:

* Campbell Scientific
* Data Garrison

[cron]: https://en.wikipedia.org/wiki/Cron
[MSC]: http://dd.weather.gc.ca/about_dd_apropos.txt

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata --source environment_canada --station XCM --destination /datastore/weather
```

This will download the sensor metadata from the Environment Canada source for the station with the identifier `XCM` (Cambridge Bay), and store the metadata in a JSON file in the `/datastore/weather` directory.

The directory `/datastore/weather/environment_canada/metadata` will be created if it does not already exist.

A file will be created at `/datastore/weather/environment_canada/metadata/XCM.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

Inside the `XCM.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

### Step 2: Uploading Sensor Metadata to OGC SensorThings API

After downloading the weather station metadata, it must be converted to OGC SensorThings API entities and uploaded to a service. According to the OGC SensorThings API specification, entities must be created for the following hierarchy.

A `Thing` represents the station as a uniquely identifiable object. This `Thing` has a `Location`, corresponding to the geospatial position of the weather station (typically a Point).

The weather station measures multiple phenomena, each assigned their own `Observed Property` entity (which can be re-used across the global SensorThings API namespace or a new entity created just for that weather station).

Each phenomena is measured using a `Sensor`, which describes the physical device or procedure that records the phenomena.

The phenomena `Observed Property` and `Sensor` are linked to a new `Datastream` under the shared `Thing` entity. The `Datastream` contains the metadata for the `Observations` as a whole set, such as the unit of measurement.

Other entities such as the `Feature of Interest` and `Observation` are handled in a later step.

To execute the upload, the tool has a put command:

```
$ transload put metadata --source environment_canada --station XCM --destination /datastore/weather
```

In this case, the tool will upload the sensor metadata from the Environment Canada source for the station with the identifier `XCM` (Cambridge Bay), and look for the metadata in a JSON file in the `/datastore/weather/environment_canada` directory.

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `/datastore/weather/environment_canada/metadata/XCM.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

### Step 3: Downloading Sensor Observations

After the base entities have been created in the OGC SensorThings API service, the observation can be downloaded from the data source. The tool will download the latest observations and store them on the local filesystem.

```
$ transload get observations --source environment_canada --station XCM --destination /datastore/weather
```

In this example, observations for the Environment Canada station `XCM` (Cambridge Bay) are downloaded to a local cache in the `/datastore/weather/environment_canada/XCM/YYYY/MM/DD/HHMMSS.xml` file. The year/month/day and hour/minute/second are parsed from the observation file provided by the data source.

If a file already exists with the same name, it is **overwritten**.

### Step 4: Uploading Sensor Observations to OGC SensorThings API

TODO

## Development Instructions

TODO

## Authors

James Badger (<james@jamesbadger.ca>)

## License

GNU General Public License version 3
