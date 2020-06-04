# Arctic Sensor Web Data Transloader

[![Build Status](https://travis-ci.org/GeoSensorWebLab/data-transloader.svg?branch=master)](https://travis-ci.org/GeoSensorWebLab/data-transloader)

This tool downloads weather station data from multiple sources and uploads it to an [OGC SensorThings API][] service. This makes the data available using an open and interoperable API.

[OGC SensorThings API]: https://docs.opengeospatial.org/is/15-078r6/15-078r6.html

## Setup Instructions

This tool requires [Ruby][] 2.4 or newer. Once Ruby is installed, you will need to install [Bundler][] to install the library dependencies.

```
$ cd data-transloader
$ gem install bundler
$ bundle install
```

This tool should be runnable on Linux, MacOS, and Windows.

[Bundler]: https://bundler.io
[Ruby]: https://www.ruby-lang.org/en/

## Docker

The tool can also be ran inside a Docker container, without having to install Ruby at all. See the [Docker Instructions](DOCKER.markdown) for details.

## Usage

This tool is meant to be scriptable using [cron][], a scheduling daemon, to automate imports on a schedule. This is done by passing in command line arguments to the tool that handle the sensor metadata and observation download/upload.

The tool is separated into downloading/uploading metadata and downloading/uploading observation data. This is because metadata is not often updated from the source, and the metadata *may* need manual correction by the data transloader user. The observation data is constantly updated, so it needs to be efficient and avoid checking/creating entities for metadata every time it is run.

Currently supported weather station sources:

* Data Garrison
* [Environment Canada][MSC]
* Campbell Scientific
* Historical weather and energy usage data from the Arctic Institute of North America's research stations

[cron]: https://en.wikipedia.org/wiki/Cron
[MSC]: https://dd.weather.gc.ca/about_dd_apropos.txt

### Instructions by Data Provider

Different source data providers have moderately different implementations and usage. Please see the detailed documentation for an explanation of the source-to-SensorThings API mappings.

* [Campbell Scientific Weather Stations](docs/CAMPBELL_SCIENTIFIC.md)
* [Data Garrison Weather Stations](docs/DATA_GARRISON.md)
* [Environment Canada Weather Stations](docs/ENVIRONMENT_CANADA.md)
* [Kluane Lake Research Station Historical Energy Usage Data](docs/KLRS_HISTORICAL_ENERGY.md)
* [Kluane Lake Research Station Historical Weather Data](docs/KLRS_HISTORICAL_WEATHER.md)

## Development Instructions

This tool can be modified and extended by editing its source files. In this environment, you must tell Bundler to also install the "test" group gems:

```
$ bundle install --with test
```

## Authors

James Badger (<james@jamesbadger.ca>)

## License

GNU General Public License version 3
