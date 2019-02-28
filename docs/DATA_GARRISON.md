# Loading Data from Data Garrison

The following instructions are for setting up station data and uploading observations to SensorThings API with data from [Data Garrison][DG].

[DG]: https://datagarrison.com

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata \
    --source data_garrison \
    --user 300234063581640 \
    --station 300234065673960 \
    --cache /datastore/weather
```

This will download the sensor metadata from the Data Garrison source for the user with ID `300234063581640` and station with the identifier `300234065673960`, and store the metadata in a JSON file in the `/datastore/weather` directory.

The directory `/datastore/weather/data_garrison/metadata` will be created if it does not already exist.

A file will be created at `/datastore/weather/data_garrison/metadata/300234063581640/300234065673960.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

Inside the `300234065673960.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

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
    --source data_garrison \
    --user 300234063581640 \
    --station 300234065673960 \
    --cache /datastore/weather \
    --destination https://example.org/v1.0/
```

In this case, the tool will upload the sensor metadata from the Data Garrison weather station with the ID `300234065673960` for the user with ID `300234063581640`, and look for the metadata in a JSON file in the `/datastore/weather/data_garrison` directory.

An OGC SensorThings API server is expected to have a root resource available at `https://example.org/v1.0/`. (HTTP URLs are also supported.)

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `/datastore/weather/data_garrison/metadata/300234063581640/300234065673960.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

WIP

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

* Thing
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * Properties (JSON object with Transceiver/Logger details)
* Location
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * encodingType (GeoJSON)
    * location (GeoJSON, must be added in cached file)
* Datastream
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * unitOfMeasurement (from Units, will probably need lookup table)
    * observationType (OM_Observation)
    * observedArea (Not used)
    * phenomenonTime (Not used)
    * resultTime (Not used)
* Sensor
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * encodingType (application/pdf due to limitation)
    * metadata (link to metadata page)
* Observed Property
    * Name (from metadata)
    * Description (longer form of Name)
    * Definition (link to example.org for now, later can link to dictionary site)
* Observation
    * phenomenonTime (from "Latest Conditions" time, timezone must be manually added to metadata cached file)
    * result (from latest value in sidebar)
    * resultTime (Not used)
    * resultQuality (Not used)
    * valudTime (Not used)
    * parameters (Not used)
* FeatureOfInterest
    * Entity is omitted; will be generated by server from Location entity

## Future Work: Loading from TSV

Data Garrison provides the entire history of the station in a list of downloadable files. The files are available in HOBOware or tab-delimited value files. Instead of loading the observations from the HTML on the station page, the observations could be parsed from the TSV file.

As the TSV file can be a long file, it can be over a MB to download. This is somewhat of a waste of bandwidth to download every hour for each station. Fortunately the server is Apache and supports HTTP caching headers.

When executing a `HEAD` request for the TSV file, the following headers are provided:

* [Date](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date)
* [Last-Modified](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified)
* [ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
* [Accept-Ranges](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Ranges)
* [Content-Length](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Length)

"Accept-Ranges" means we can request only part of the file, cutting back on the bandwidth used. The process could be as follows.

1. Retrieve metadata for a station
2. Metadata is stored in station metadata cache file, which would include the list of downloadable TSV files
3. Metadata cache file would also have a history state parameter, which would include:
    * The byte offset to which data had been downloaded for each TSV file
    * The last-downloaded date for each TSV file that could be compared to the "Last-Modified" header
    * The last parsed Observation phenomenon time from each TSV file
4. The state could then be used to check if new data was available from the server, using a low-bandwidth `HEAD` request
5. If new data is available, use a `GET` request with the [`Range` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range), using the last known byte offset as the *start* of the range to only retrieve the newest part of the file
6. The transloader would then parse the file and remove any headers, and determine which readings are new and need to be cached as observations in the file system

This is a more advanced method of retrieving Observation data than from the HTML on the station page. It requires more coding and is more complicated. It also provides the ability to download all historical data for a station.

It might be possible to use the [`If-Range` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Range) or [`If-None-Match`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-None-Match) to request the partial document, although I haven't tested it.

Potential Issue: The only way to check if a new download file has been created (e.g. when the station is reset) is to re-download the metadata every time the observations are fetched. This is a small waste of bandwidth.
