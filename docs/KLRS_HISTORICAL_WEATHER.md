# Loading Data from Historical KLRS Weather Data

The historical weather dataset for the Kluane Lake Research Station was collected in 2012, 2013, and 2014 by an automated weather station (AWS) set up by the SFU Glaciology Lab. Please contact the Arctic Institute of North America for the original source CSV data.

## Prerequisites

In order to load the historical data into OGC SensorThings API, you will need the original CSV files. Each has a name like `TOA5_5264.FiveMin.dat`.

For more information on the "TOA5" format, I recommend searching the web for a Campbell Scientific datalogger manual that covers the "TOA5 ASCII File Format."

### Step 1: Parsing Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be parsed using a command:

```
$ transload get metadata \
    --provider klrs_h_weather \
    --station_id KLRS_5264 \
    --data_path "data/TOA5_5264.FiveMin.dat" \
    --database_url file://datastore/weather
```

This will parse the sensor metadata from the source and store the metadata in a JSON file in the `datastore/weather` directory. The string "KLRS_5264" is an arbitary identification string for *this* station; changing this will create a separate set of entities in OGC SensorThings API.

The directory `datastore/weather/klrs_h_weather/metadata` will be created if it does not already exist.

A file will be created at `datastore/weather/klrs_h_weather/metadata/KLRS_5264.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

**Note:** You may specify *additional* data files to parse by using multiple `--data_path` arguments in the command. At least one data file path must be specified.

Inside the `KLRS_5264.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

**Please Note**

For the KLRS historical weather station data, you *may* add the `elevation` (in metres above mean sea level), but it is optional.

The latitude, longitude, and time zone offset are hard-coded for this ETL module. This means you do not need to manually update them in the metadata file.

* Edit any mis-named sensors
* Optional: add elevation

### Step 2: Uploading Sensor Metadata to OGC SensorThings API

After downloading the weather station metadata, it must be converted to OGC SensorThings API entities and uploaded to a service. According to the OGC SensorThings API specification, entities must be created for the following hierarchy.

A `Thing` represents the station as a uniquely identifiable object. This `Thing` has a `Location`, corresponding to the geospatial position of the weather station (typically a Point).

The weather station measures multiple phenomena, each assigned their own `Observed Property` entity (which can be re-used across the global SensorThings API namespace or a new entity created just for that weather station).

Each phenomena is measured using a `Sensor`, which describes the physical device or procedure that records the phenomena.

The phenomena `Observed Property` and `Sensor` are linked to a new `Datastream` under the shared `Thing` entity. The `Datastream` contains the metadata for the `Observations` as a whole set, such as the unit of measurement.

Other entities such as the `Feature of Interest` and `Observation` are handled in a later step.

To execute the upload, the tool has a put command:

```
$ transload put metadata \
    --provider klrs_h_weather \
    --station_id KLRS_5264 \
    --database_url file://datastore/weather \
    --destination https://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In this step, the tool will upload the sensor metadata from the weather station with the ID `KLRS_5264`, and look for the metadata in a JSON file in the `datastore/weather/klrs_h_weather` directory.

An OGC SensorThings API server is expected to have a root resource available at `https://scratchpad.sensorup.com/OGCSensorThings/v1.0/`. (HTTP URLs are also supported.)

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `datastore/weather/klrs_h_weather/metadata/KLRS_5264.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

### Step 3: Parsing Sensor Observations

After the base entities have been created in the OGC SensorThings API service, the observations can be parsed from the data source files. The tool will parse the latest observations and store them on the local filesystem in an intermediary schema.

```
$ transload get observations \
    --provider klrs_h_weather \
    --station_id KLRS_5264 \
    --database_url file://datastore/weather
```

In this example, the weather station with the ID `KLRS_5264` will have its observations parsed and converted into the `datastore/weather/klrs_h_weather/KLRS_5264` directory.

When the observation rows are parsed from the source data file, they are adjusted into UTC timestamps and separated by day into their own cache files.

A sample observation cache file directory: `datastore/weather/klrs_h_weather/KLRS_5264/2013/05/26.csv`

Observations are separated into files by day to avoid one very-large observations file.

When observations are parsed into cache files, the latest parsed observation from the station has its date timestamp stored in the station metadata cache file for debugging.

The filename will use the **UTC** version of the date, not the local time for the station. This should make it easier to specify a custom date in the next step without having to deal with timezones.

If an observation cache file already exists with the same name, it is re-opened and merged with the newer observations. Newer observations with the same timestamp will replace older observations in the cache file. This will likely happen as the data logger outputs files with the same filename (e.g. `TOA5_5264.FiveMin.dat`).

### Step 4: Uploading Sensor Observations to OGC SensorThings API

Once the original observations have been parsed, they can be converted to OGC SensorThings API entities and uploaded to a compatible service.

A new `Observation` entity is created that contains the readings for the weather station observation. If an identical `Observation` already exists on the remote service, then no upload is done. If an `Observation` already exists under the same `Datastream` with the same timestamp but a different reading value, then the value is updated with a `PUT` request. If no `Observation` already exists, then a new one is created with a `POST` request.

The `FeatureOfInterest` for the `Observation` will be automatically generated on the server based on the linked `Location`.

```
$ transload put observations \
    --provider klrs_h_weather \
    --station_id KLRS_5264 \
    --database_url file://datastore/weather \
    --date 2018-05-01T00:00:00Z/2018-05-02T00:00:00Z \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In the example above, the observations for weather station with ID `KLRS_5264` are read from the filesystem cache. All observations in the time interval specificied will be uploaded. In the cached observations, any observation that matches the date timestamp will be uploaded; if there are no matches, then a warning will be printed.

If your SensorThings API instance requires authentication or special headers, please see [http_customization.md](http_customization.md) for instructions on setting that up with the command line tool.

Optionally, a list of allowed or blocked datastreams can be specified on the command line to limit the data that is uploaded to SensorThings API. See the command-line tool help information for `--allowed` and `--blocked`.

## Data Model Mapping

Here is how the metadata and data from Campbell Scientific are mapped to SensorThings API entities.

In a data file, the first line contains metadata headers:

```
"File Format", "Station Name", "Logger Model", "Logger Serial Number", "Operating System Version", "DLD File", "DLD Signature", "Table Name"
```

Here is a sample:

```
"TOA5","5264","CR1000","5264","CR1000.Std.10","CRD:KLRS_May2013.CR1","36023","FiveMin"
```

This parses out to the following:

* File Format: `TOA5`
* Station Name: `5264`
* Logger Model: `CR1000`
* Logger Serial Number: `5264`
* Operating System Version: `CR1000.Std.10`
* DLD File: `CRD:KLRS_May2013.CR1`
* DLD Signature: `36023`
* Table Name: `FiveMin`

The above items will be stored as metadata under the `properties` attribute for the `Thing` entity. 

The next headers in the source data files delineate the Observed Properties and Units of Measurement. These will be parsed into Datastreams as well for the Thing entity.

There is no latitude/longitude or location information, nor is there any timezone information. Normally these need to be manually added to the metadata cache file, but as this module is designed for a *specific* station, the values have been hard-coded instead.

### SensorThings API Entities

* `Thing`
    * Name (from station ID as specified on command line)
        * e.g. `Historical Weather: KLRS_5264`
    * Description (longer form of Name)
    * Properties (JSON object with station details)
* `Location`
    * Name (from station ID)
    * Description (longer form of Name)
    * encodingType (`application/vnd.geo+json`)
    * location (GeoJSON, uses lat/lon from metadata cache file)
* `Datastream`
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * unitOfMeasurement (from units in source data file)
    * observationType (OM_Observation)
    * observedArea (Not used)
    * phenomenonTime (Not used)
    * resultTime (Not used)
* `Sensor`
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * encodingType (`application/pdf` due to limitation)
    * metadata (link to metadata page)
* `ObservedProperty`
    * Name (from metadata)
    * Description (longer form of Name)
    * Definition (link to online Ontology/Dictionary)
* `Observation`
    * phenomenonTime (from "Latest Conditions" time, timezone must be manually added to metadata cached file)
    * result (from CSV cell)
    * resultTime (Not used)
    * resultQuality (Not used)
    * valudTime (Not used)
    * parameters (Not used)
* `FeatureOfInterest`
    * Name (same as Location)
    * Description (longer form of Name)
    * encodingType (`application/vnd.geo+json`)
    * feature (GeoJSON, uses lat/lon from metadata cache file)

