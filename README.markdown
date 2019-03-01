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

* Data Garrison
* [Environment Canada][MSC]

Weather station sources with planned support:

* Campbell Scientific

[cron]: https://en.wikipedia.org/wiki/Cron
[MSC]: http://dd.weather.gc.ca/about_dd_apropos.txt

### Environment Canada

For detailed instructions, see [docs/ENVIRONMENT_CANADA.md](docs/ENVIRONMENT_CANADA.md).

### Data Garrison

For detailed instructions, see [docs/DATA_GARRISON.md](docs/DATA_GARRISON.md).

## Development Instructions

This tool can be modified and extended by editing its source files. There are no special requirements for development after following the "Setup Instructions" section above.

## Authors

James Badger (<james@jamesbadger.ca>)

## License

GNU General Public License version 3
