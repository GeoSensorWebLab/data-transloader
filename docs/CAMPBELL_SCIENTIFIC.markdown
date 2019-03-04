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

TODO: The tool will support loading *multiple* data files, allowing you to import historical observations.

### Step 1: Downloading Sensor Metadata

To conform to the OGC SensorThings API entity model, the `Thing`, `Location`, `Sensors`, `Observed Properties`, and `Datastreams` must be initialized using the weather station details before sensor data observations can be uploaded. The metadata can be downloaded using a command:

```
$ transload get metadata \
    --source campbell_scientific \
    --station 606830 \
    --dataurl "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat" \
    --cache /datastore/weather
```

This will download the sensor metadata from the Campbell Scientific source for the station with the ID `606830`, monitor the given data URL for observation updates, and store the metadata in a JSON file in the `/datastore/weather` directory.

The directory `/datastore/weather/campbell_scientific/metadata` will be created if it does not already exist.

A file will be created at `/datastore/weather/campbell_scientific/metadata/606830.json`; if it already exists, it will be **overwritten**. Setting up automated backups of this directory is recommended.

**Note:** You may specify *additional* data files to monitor by using multiple `--dataurl` arguments in the command. At least one data URL must be specified.

Inside the `606830.json` file the sensor metadata will be stored. Editing these values will affect the metadata that is stored in SensorThings API in the metadata upload step. This file also will store the URLs to the SensorThings API entities, which is used by a later step to upload Observations without first having to crawl the SensorThings API instance.

**Please Note**

For Campbell Scientific weather stations, you must manually edit the metadata cache file to add the latitude and longitude of the station. Adding the `elevation` (in metres above mean sea level) is optional.

The local timezone offset for the station must also be added, as it is not available on the station data page. Use ISO 8601 compatible time offsets for the time zone; e.g. `-07:00`, `+01:00`, `+03:00`, `Z`.

* Add Latitude and Longitude
* Edit any mis-named sensors
* Add time zone offset
* Optional: add elevation

WIP