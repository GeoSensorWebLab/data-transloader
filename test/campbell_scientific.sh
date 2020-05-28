#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
PROVIDER="campbell_scientific"
STATION_ID="606830"
DATASTORE="file:///Volumes/ramdisk/datastore/weather"
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"
NOW=$(ruby -e "puts (Time.new).utc.strftime('%FT%T%z')")
THEN=$(ruby -e "puts (Time.new - (24*3600)).utc.strftime('%FT%T%z')")
INTERVAL="$THEN/$NOW"

# Campbell Scientific Test Run
time ruby $SCRIPT get metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --data_url "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat" \
    --database_url $DATASTORE \
    --overwrite

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --key "latitude" \
    --value "68.983639" > /dev/null

ruby $SCRIPT set metadata \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --key "longitude" \
    --value "-105.835833" > /dev/null

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
    --database_url $DATASTORE \
    --destination $DESTINATION \
    --blocked LdnCo_Avg,Ux_Avg,Uy_Avg,Uz_Avg,CO2_op_Avg,H2O_op_Avg,Pfast_cp_Avg,xco2_cp_Avg,xh2o_cp_Avg,mfc_Avg    

time ruby $SCRIPT get observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE

time ruby $SCRIPT put observations \
    --provider $PROVIDER \
    --station_id $STATION_ID \
    --database_url $DATASTORE \
    --date "$INTERVAL" \
    --destination $DESTINATION \
    --blocked LdnCo_Avg,Ux_Avg,Uy_Avg,Uz_Avg,CO2_op_Avg,H2O_op_Avg,Pfast_cp_Avg,xco2_cp_Avg,xh2o_cp_Avg,mfc_Avg
