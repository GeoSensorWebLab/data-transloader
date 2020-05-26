#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
PROVIDER="data_garrison"
STATION_ID="300234065673960"
USER_ID="300234063581640"
DATASTORE="/Volumes/ramdisk/datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"
NOW=$(ruby -e "puts (Time.new).utc.strftime('%FT%T%z')")
THEN=$(ruby -e "puts (Time.new - (24*3600)).utc.strftime('%FT%T%z')")
INTERVAL="$THEN/$NOW"

# Data Garrison Test Run
ruby $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --overwrite

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --key "latitude" \
    --value "69.158"

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --key "longitude" \
    --value "-107.0403"

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --key "timezone_offset" \
    --value "-06:00"

ruby $SCRIPT put metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --destination $DESTINATION

ruby $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE

ruby $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --cache $DATASTORE \
    --date "$INTERVAL" \
    --destination $DESTINATION
