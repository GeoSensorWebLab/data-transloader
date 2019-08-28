# Loading Data from Data Garrison

The following instructions are for setting up station data and uploading observations to SensorThings API with data from [Data Garrison][DG].

[DG]: https://datagarrison.com

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata \
    --provider data_garrison \
    --user_id 300234063581640 \
    --station_id 300234065673960 \
    --cache datastore/weather
```

This will download the sensor metadata from the Data Garrison source for the user with ID `300234063581640` and station with the identifier `300234065673960`, and store the metadata in a JSON file in the `datastore/weather` directory.

The directory `datastore/weather/data_garrison/metadata` will be created if it does not already exist.

Inside the `300234065673960.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

The station information page will list one or more data files with historical observations for this station. The data transloader tool will cache information about those data files and will download the historical observations in the "download observations" step below.

**Please Note**

For Data Garrison weather stations, you must manually edit the metadata cache file for any sensor naming errors and to add the latitude and longitude of the station. Adding the `elevation` (in metres above mean sea level) is optional.

The local timezone offset for the station must also be added, as it is not available on the station data page. Use ISO 8601 compatible time offsets for the time zone; e.g. `-07:00`, `+01:00`, `+03:00`, `Z`.

* Add Latitude and Longitude
* Edit any mis-named sensors
* Add time zone offset
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
    --provider data_garrison \
    --user_id 300234063581640 \
    --station_id 300234065673960 \
    --cache datastore/weather \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In this case, the tool will upload the sensor metadata from the Data Garrison weather station with the ID `300234065673960` for the user with ID `300234063581640`, and look for the metadata in a JSON file in the `datastore/weather/data_garrison` directory.

An OGC SensorThings API server is expected to have a root resource available at `https://example.org/v1.0/`. (HTTP URLs are also supported.)

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `datastore/weather/data_garrison/metadata/300234063581640/300234065673960.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

### Step 3: Downloading Sensor Observations

After the base entities have been created in the OGC SensorThings API service, the observation can be downloaded from the data source. The tool will download the observations from all linked data files and store them on the filesystem.

After the observations have been downloaded once, the next run of the tool will attempt to only download the newer parts of the files from Data Garrison (by using HTTP Ranges). If the files have not been updated, then no observations are downloaded. If the files are longer than they were the last time the tool was run, only the new section is downloaded and parsed for observations. If the files are shorter than last time, the tool assumes the files have been reset and will re-download the files entirely.

```
$ transload get observations \
    --provider data_garrison \
    --user_id 300234063581640 \
    --station_id 300234065673960 \
    --cache datastore/weather
```

In this example, the observations from the data files listed on the page for the Data Garrison weather station with the ID `300234065673960` for the user with ID `300234063581640` are downloaded to a local cache.

### Step 4: Uploading Sensor Observations to OGC SensorThings API

Once the original observations have been downloaded to disk, they can be converted to OGC SensorThings API entities and uploaded to a compatible service.

A `Feature of Interest` entity will be created for the observation, based on the location of the feature being observed. For a stationary weather station, this will be a point that does not move and any existing matching entity will be re-used on the OGC SensorThings API service. For a mobile sensor device, the location for this entity will likely be changing and a new entity will be created on the remote service for each `Observation`.

Once a `Feature of Interest` has been created or found, it is linked to a new `Observation` entity that contains the readings for the weather station observation. If an identical `Observation` already exists on the remote service, then no upload is done. If an `Observation` already exists under the same `Datastream` with the same timestamp but a different reading value, then the value is updated with a `PUT` request. If no `Observation` already exists, then a new one is created with a `POST` request.

```
$ transload put observations \
    --provider data_garrison \
    --user_id 300234063581640 \
    --station_id 300234065673960 \
    --cache datastore/weather \
    --date 2018-05-01T00:00:00Z/2018-05-02T00:00:00Z \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In the example above, the observations for Data Garrison weather station with ID `300234065673960` for user with ID `300234063581640` are read from the filesystem cache. Only cached files with dates that fall into the time interval will be uploaded.

If your SensorThings API instance requires authentication or special headers, please see [http_customization.md](http_customization.md) for instructions on setting that up with the command line tool.

Optionally, a list of allowed or blocked datastreams can be specified on the command line to limit the data that is uploaded to SensorThings API. See the command-line tool help information for `--allowed` and `--blocked`.

## Data Model Mapping

Here is how the metadata and data from Data Garrison is mapped to SensorThings API entities.

* Transceiver Details (to `Thing` properties)
    * ID
    * Transmission Interval
    * Network
    * Board Revision
* Logger (to `Thing` properties)
    * Serial Number
    * Logging Interval
    * Sampling Interval
    * Part Number

The above items will be stored as metadata under the `properties` attribute for the `Thing` entity. Other metadata from Data Garrison is excluded as it would require constant updates as the data values change, and the `Thing` metadata is not continuously updated in this transloader application.

* Sensors (to Sensor, Datastream, Observed Property, Unit of Measurement)
    * e.g. "Pressure" (to Observed Property)
        * Units (to UoM)

Additional metadata *could* be stored in the `Sensor` entity under  the `metadata` attribute, but that attribute is limited to `pdf` and `SensorML` currently (this is a limitation in GOST). Instead, a link to the station metadata page will be used as the `metadata` value.

I noticed that in some Data Garrison stations, the metadata for some of the sensors was incorrect. This must then be manually corrected by editing the metadata cache file after the "get metadata" step.

There is also no latitude/longitude or location information. This must be manually added to the metadata cache file as well.

### SensorThings API Entities

* `Thing`
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * Properties (JSON object with Transceiver/Logger details)
* `Location`
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * encodingType (`application/vnd.geo+json`)
    * location (GeoJSON, uses lat/lon from metadata cache file)
* `Datastream`
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * unitOfMeasurement (from Units, will probably need lookup table)
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
    * Definition (link to example.org for now, later can link to dictionary site)
* `Observation`
    * phenomenonTime (from "Latest Conditions" time, timezone must be manually added to metadata cached file)
    * result (from latest value in sidebar)
    * resultTime (Not used)
    * resultQuality (Not used)
    * valudTime (Not used)
    * parameters (Not used)
* `FeatureOfInterest`
    * Name (same as Location)
    * Description (longer form of Name)
    * encodingType (`application/vnd.geo+json`)
    * feature (GeoJSON, uses lat/lon from metadata cache file)
