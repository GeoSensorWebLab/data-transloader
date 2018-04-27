# Arctic Sensor Web Data Transloader

This tool downloads weather station data from multiple sources and uploads it to an OGC SensorThings API service. This makes the data available using an open and interoperable API.

## Setup Instructions

TODO

## Usage

This tool is meant to be scriptable using cron, a scheduling daemon, to automate imports on a schedule. This is done by passing in command line arguments to the tool that handle the sensor metadata and observation download/upload.

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata --source environment_canada --station XCM --destination /datastore/weather
```

This will download the sensor metadata from the Environment Canada source for the station with the identifier `XCM` (Cambridge Bay), and store the metadata in a JSON file in the `/datastore/weather` directory.

The directory `/datastore/environment_canada/metadata` will be created if it does not already exist.

A file will be created at `/datastore/environment_canada/metadata/XCM.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

Inside the `XCM.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

### Step 2: Uploading Sensor Metadata to OGC SensorThings API

TODO

### Step 3: Downloading Sensor Observations

TODO

### Step 4: Uploading Sensor Observations to OGC SensorThings API

TODO

## Development Instructions

TODO

## Authors

James Badger (<james@jamesbadger.ca>)

## License

GNU General Public License version 3
