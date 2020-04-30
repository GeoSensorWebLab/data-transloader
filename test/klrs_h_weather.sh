#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
PROVIDER="klrs_h_weather"
STATION_ID="KLRS_5264"
DATASTORE="datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"
NOW=$(ruby -e "puts (Time.new).utc.strftime('%FT%T%z')")
THEN=$(ruby -e "puts (Time.new - (24*3600)).utc.strftime('%FT%T%z')")
INTERVAL="$THEN/$NOW"

echo "$INTERVAL"

# KLRS Historical Weather Dadta Test Run
ruby $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --data_path "tmp/klrs-weather/2012/September/TOA5_5264.FiveMin.dat" \
    --data_path "tmp/klrs-weather/2013/July/TOA5_5264.FiveMin.dat" \
    --cache $DATASTORE \
    --overwrite

ruby $SCRIPT put metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --cache $DATASTORE \
    --destination $DESTINATION

ruby $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --cache $DATASTORE

ruby $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --cache $DATASTORE \
    --date $INTERVAL \
    --destination $DESTINATION
