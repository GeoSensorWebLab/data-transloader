# Loading Data from Campbell Scientific

The following instructions are for setting up station data and uploading observations to SensorThings API with data from [Campbell Scientific][CS].

[CS]: https://www.campbellsci.ca

## Prerequisites

In order to download the station metadata and observations, you will need two things from a Campbell Scientific weather station:

* The station ID number
* At least one data file URL

The station ID number can be extracted from the station URL. For example, the following URL would extract to the ID `606830`.

http://dataservices.campbellsci.ca/sbd/606830/

The data files contain the observations and some of the station metadata. However, the data files names cannot be auto-discovered and must be manually specified or added to the station metadata cache file. For the station noted above, the data files can be found by adding `/data/` to the end of the URL:

http://dataservices.campbellsci.ca/sbd/606830/data/

This will list the data files, with subdirectories containing more data files. In the following guide I will be using the following data file URL:

http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat

Note that if the name of the data file changes, the station metadata cache file must be updated or else the data transloader will not find new observations.

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata \
    --source campbell_scientific \
    --station 606830 \
    --dataurl "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat" \
    --cache datastore/weather
```

This will download the sensor metadata from the Campbell Scientific source for the station with the ID `606830`, monitor the given data URL for observation updates, and store the metadata in a JSON file in the `datastore/weather` directory.

The directory `datastore/weather/campbell_scientific/metadata` will be created if it does not already exist.

A file will be created at `datastore/weather/campbell_scientific/metadata/606830.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

**Note:** You may specify *additional* data files to monitor by using multiple `--dataurl` arguments in the command. At least one data URL must be specified.

Inside the `606830.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

**Please Note**

For Campbell Scientific weather stations, you must manually edit the metadata cache file to add the latitude and longitude of the station. Adding the `elevation` (in metres above mean sea level) is optional.

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
    --source campbell_scientific \
    --station 606830 \
    --cache datastore/weather \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In this case, the tool will upload the sensor metadata from the Campbell Scientific weather station with the ID `606830`, and look for the metadata in a JSON file in the `datastore/weather/campbell_scientific` directory.

An OGC SensorThings API server is expected to have a root resource available at `https://example.org/v1.0/`. (HTTP URLs are also supported.)

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `datastore/weather/campbell_scientific/metadata/606830.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

### Step 3: Downloading Sensor Observations

After the base entities have been created in the OGC SensorThings API service, the observation can be downloaded from the data source. The tool will download the latest observations and store them on the local filesystem.

```
$ transload get observations \
    --source campbell_scientific \
    --station 606830 \
    --cache datastore/weather
```

In this example, the Campbell Scientific weather station with the ID `606830` will have its observations downloaded into the `datastore/weather/campbell_scientific/606830` directory.

For each data file defined in the station metadata cache file, a subdirectory is created using the filename. When the observation rows are parsed from the source data file, they are adjusted into UTC timestamps and separated by day into their own cache files.

A sample observation cache file directory: `datastore/weather/campbell_scientific/606830/CBAY_MET_1HR.dat/2019/03/05.csv`

Observations are separated into files by day to avoid one very-large observations file. Additionally, if the source data file is reset or truncated then the local observation cache files are unaffected (as opposed to storing the original source data file on disk).

When observations are parsed into cache files, the latest parsed observation from the station has its date timestamp stored in the station metadata cache file for debugging. The byte offset of the downloaded source data file is also stored and used with [HTTP Byte Ranges](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range) to avoid downloading the entire source data file.

HTTP requests to download the source data files will have gzip encoding *disabled*, as that header would disable the usage of the 'Range' header.

The filename will use the **UTC** version of the date, not the local time for the station. This should make it easier to specify a custom date in the next step without having to deal with timezones.

If an observation cache file already exists with the same name, it is re-opened and merged with the newer observations. Newer observations with the same timestamp will replace older observations in the cache file.

### Step 4: Uploading Sensor Observations to OGC SensorThings API

Once the original observations have been downloaded to disk, they can be converted to OGC SensorThings API entities and uploaded to a compatible service.

A new `Observation` entity is created that contains the readings for the weather station observation. If an identical `Observation` already exists on the remote service, then no upload is done. If an `Observation` already exists under the same `Datastream` with the same timestamp but a different reading value, then the value is updated with a `PUT` request. If no `Observation` already exists, then a new one is created with a `POST` request.

The `FeatureOfInterest` for the `Observation` will be automatically generated on the server based on the linked `Location`.

```
$ transload put observations \
    --source campbell_scientific \
    --station 606830 \
    --cache datastore/weather \
    --date 20180501T00:00:00Z \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In the example above, the observations for Campbell Scientific weather station with ID `606830` are read from the filesystem cache in `datastore/weather/campbell_scientific/606830/*/2018/05/01.csv`. This is done for all the data files defined for the station in the station metadata cache file. In the CSV file(s), any observation that matches the date timestamp will be uploaded; if there are no matches, then a warning will be printed.

```
$ transload put observations \
    --source campbell_scientific \
    --station 606830 \
    --cache datastore/weather \
    --date latest \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In the second example, the newest observations will be automatically determined by reading the station metadata cache file. For each data file, the most-recently-uploaded observation timestamp is kept and used to determine which observations should be uploaded. If no such value is found in the cache file, then only the latest downloaded observation will be uploaded.

The second example is recommended usage, as it automatically uses the cache to upload only new observations.

TODO: Update this with an option for uploading all observations since last known, or in time range.

## Data Model Mapping

Here is how the metadata and data from Campbell Scientific are mapped to SensorThings API entities.

* Station Details (to `Thing` properties)
    * Station ID
    * Station Model Name
    * Station Serial Number
    * Station Program Name

The above items will be stored as metadata under the `properties` attribute for the `Thing` entity. 

* Observed Property CSV columns (to Sensor, Datastream, Observed Property, Unit of Measurement)
    * Name (e.g. "TEMPERATURE_Avg") to Observed Property, Sensor Name, Datastream Name
    * Units to UoM
    * (Not used) Observation type to Datastream Observation type (e.g. average value vs peak value)

There is no latitude/longitude or location information, nor is there any timezone information. These must be manually added to the metadata cache file. A timezone is necessary as the data files use timestamps *without* timezones or timezone offsets.

### SensorThings API Entities

* `Thing`
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * Properties (JSON object with station details)
* `Location`
    * Name (from station ID, or customized in cached file)
    * Description (longer form of Name)
    * encodingType (`application/vnd.geo+json`)
    * location (GeoJSON, uses lat/lon from metadata cache file)
* `Datastream`
    * Name (from station ID and observed property)
    * Description (longer form of Name)
    * unitOfMeasurement (from units, will probably need lookup table)
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

