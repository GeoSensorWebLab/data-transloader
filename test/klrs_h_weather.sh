#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

RUBY="ruby -Ilib"
SCRIPT="transload"
PROVIDER="klrs_h_weather"
STATION_ID="KLRS_5264"
DATASTORE="postgres://localhost:5432/etl"
# DATASTORE="file:///Volumes/ramdisk/datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"

# KLRS Historical Weather Data Test Run
time $RUBY $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --data_path "tmp/klrs-weather/2012/September/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2013/July/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2013/July/TOA5_5264.Health.dat" \
    --data_path "tmp/klrs-weather/2013/May/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2013/May/TOA5_5264.Health.dat" \
    --data_path "tmp/klrs-weather/2014/July/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2014/July/TOA5_5264.Health.dat" \
    --data_path "tmp/klrs-weather/2014/May/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2014/May/TOA5_5264.Health.dat" \
    --data_path "tmp/klrs-weather/2014/September/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2014/September/TOA5_5264.Health.dat" \
    --database_url $DATASTORE \
    --overwrite

time $RUBY $SCRIPT put metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --destination $DESTINATION

time $RUBY $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE

# Upload partial 2012 observations only to save time (approx 4600).
# (For a local SensorThings API instance, 250,000 observations takes 
# about 45 minutes to upload.)
time $RUBY $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --date "2012-08-01T00:00:00Z/2012-08-07T00:00:00Z" \
    --destination $DESTINATION
