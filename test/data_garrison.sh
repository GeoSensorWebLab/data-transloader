#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
PROVIDER="data_garrison"
STATION_ID="300234065673960"
USER_ID="300234063581640"
DATASTORE="file:///Volumes/ramdisk/datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"
NOW=$(ruby -e "puts (Time.new).utc.strftime('%FT%T%z')")
THEN=$(ruby -e "puts (Time.new - (24*3600)).utc.strftime('%FT%T%z')")
INTERVAL="$THEN/$NOW"

# Data Garrison Test Run
time ruby $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --overwrite

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --key "latitude" \
    --value "69.158" > /dev/null

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --key "longitude" \
    --value "-107.0403" > /dev/null

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --key "timezone_offset" \
    --value "-06:00" > /dev/null

time ruby $SCRIPT put metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --destination $DESTINATION

time ruby $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE

time ruby $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --user_id $USER_ID \
    --database_url $DATASTORE \
    --date "$INTERVAL" \
    --destination $DESTINATION
