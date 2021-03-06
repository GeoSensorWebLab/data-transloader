#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
PROVIDER="klrs_h_energy"
STATION_ID="KLRS_Office_Energy"
DATASTORE="file:///Volumes/ramdisk/datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"

# KLRS Historical Energy Usage Data Test Run
time ruby $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --data_path "tmp/klrs-energy/gen_april.xls" \
    --data_path "tmp/klrs-energy/gen_may.xls" \
    --data_path "tmp/klrs-energy/gen_jun.xls" \
    --data_path "tmp/klrs-energy/gen_july.xls" \
    --data_path "tmp/klrs-energy/gen_aug.xls" \
    --data_path "tmp/klrs-energy/gen_sep.xls" \
    --database_url $DATASTORE \
    --overwrite

time ruby $SCRIPT put metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --destination $DESTINATION

time ruby $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE

# A limited interval is used to prevent this from taking too long during
# a test.
time ruby $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --date "2014-04-28T00:00:00Z/2014-04-29T00:00:00Z" \
    --destination $DESTINATION
