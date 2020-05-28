# Loading Data from Environment Canada

The following instructions are for setting up station data and uploading observations to SensorThings API with data from [Environment Canada][MSC].

[MSC]: http://dd.weather.gc.ca/about_dd_apropos.txt

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file://datastore/weather
```

This will download the sensor metadata from the Environment Canada source for the station with the identifier `CXCM` (Cambridge Bay), and store the metadata in a JSON file in the `datastore/weather` directory.

The directory `datastore/weather/environment_canada/metadata` will be created if it does not already exist.

A file will be created at `datastore/weather/environment_canada/metadata/CXCM.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

Inside the `CXCM.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

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
    --provider environment_canada \
    --station_id CXCM \
    --database_url file://datastore/weather \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In this case, the tool will upload the sensor metadata from the Environment Canada source for the station with the identifier `CXCM` (Cambridge Bay), and look for the metadata in a JSON file in the `datastore/weather/environment_canada` directory.

An OGC SensorThings API server is expected to have a root resource available at `https://example.org/v1.0/`. (HTTP URLs are also supported.)

If any of the uploads fail, the error will be logged to `STDERR`.

If the uploads succeed, then the OGC SensorThings API will respond with a URL to the newly created (or updated) resource. These URLs are stored in the station metadata file, in this case `datastore/weather/environment_canada/metadata/CXCM.json`.

The tool will try to do a search for existing similar entities on the remote OGC SensorThings API service. If the entity already exists and is identical, then the URL is saved and no `POST` or `PUT` request is made. If the entity exists but is not identical, then a `PUT` request is used to update the resource. If the entity does not exist, then a `POST` request is used to create a new entity.

### Step 3: Downloading Sensor Observations

After the base entities have been created in the OGC SensorThings API service, the observation can be downloaded from the data source. The tool will download the latest observations and store them on the local filesystem.

```
$ transload get observations \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file://datastore/weather
```

In this example, observations for the Environment Canada station `CXCM` (Cambridge Bay) are downloaded to a local cache in the `datastore/weather/environment_canada/CXCM/YYYY/MM/DD/HHMMSS+0000.xml` file. The year/month/day and hour/minute/second/time zone offset are parsed from the observation file provided by the data source.

If a file already exists with the same name, it is **overwritten**.

### Step 4: Uploading Sensor Observations to OGC SensorThings API

Once the original observations have been downloaded to disk, they can be converted to OGC SensorThings API entities and uploaded to a compatible service.

A `Feature of Interest` entity will be created for the observation, based on the location of the feature being observed. For a stationary weather station, this will be a point that does not move and any existing matching entity will be re-used on the OGC SensorThings API service. For a mobile sensor device, the location for this entity will likely be changing and a new entity will be created on the remote service for each `Observation`.

Once a `Feature of Interest` has been created or found, it is linked to a new `Observation` entity that contains the readings for the weather station observation. If an identical `Observation` already exists on the remote service, then no upload is done. If an `Observation` already exists under the same `Datastream` with the same timestamp but a different reading value, then the value is updated with a `PUT` request. If no `Observation` already exists, then a new one is created with a `POST` request.

```
$ transload put observations \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file://datastore/weather \
    --date 2018-05-01T00:00:00Z/2018-05-02T00:00:00Z \
    --destination http://scratchpad.sensorup.com/OGCSensorThings/v1.0/
```

In the example above, the observations for Environment Canada station `CXCM` are read from the filesystem cache from `datastore/weather/environment_canada/CXCM/2018/05/01/*.xml` and `datastore/weather/environment_canada/CXCM/2018/05/02/*.xml`, for timestamps that fall in the date interval given in the command.

Safety Tip: It is possible to create multiple OGC SensorThings API `Observation` entities for the same timestamp, which can confuse clients who don't expect that.

If your SensorThings API instance requires authentication or special headers, please see [http_customization.md](http_customization.md) for instructions on setting that up with the command line tool.

Optionally, a list of allowed or blocked datastreams can be specified on the command line to limit the data that is uploaded to SensorThings API. See the command-line tool help information for `--allowed` and `--blocked`.
