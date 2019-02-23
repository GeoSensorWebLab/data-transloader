# Loading Data from Data Garrison

The following instructions are for setting up station data and uploading observations to SensorThings API with data from [Data Garrison][DG].

[DG]: https://datagarrison.com

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata --source data_garrison --user 300234063581640 --station 300234065673960 --cache /datastore/weather
```

This will download the sensor metadata from the Data Garrison source for the user with ID `300234063581640` and station with the identifier `300234065673960`, and store the metadata in a JSON file in the `/datastore/weather` directory.

The directory `/datastore/weather/data_garrison/metadata` will be created if it does not already exist.

A file will be created at `/datastore/weather/data_garrison/metadata/300234063581640/300234065673960.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

Inside the `300234065673960.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

WIP
