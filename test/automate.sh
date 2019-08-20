#!/bin/bash
set -e

# This is a very simple bash script for testing the command line
# interface with a local SensorThings API server.

SCRIPT=transload
DESTINATION="http://192.168.33.77:8080/FROST-Server/v1.0/"
INTERVAL="2019-07-17T00:00:00Z/2019-07-18T00:00:00Z"

# Environment Canada Test Run
ruby $SCRIPT get metadata \
    --provider environment_canada \
    --station_id CXCM \
    --cache datastore/weather

ruby $SCRIPT put metadata \
    --provider environment_canada \
    --station_id CXCM \
    --cache datastore/weather \
    --destination $DESTINATION

ruby $SCRIPT get observations \
    --provider environment_canada \
    --station_id CXCM \
    --cache datastore/weather

ruby $SCRIPT put observations \
    --provider environment_canada \
    --station_id CXCM \
    --cache datastore/weather \
    --date $INTERVAL \
    --destination $DESTINATION

# Data Garrison Test Run
ruby $SCRIPT get metadata \
    --provider data_garrison \
    --station_id 300234065673960 \
    --user_id 300234063581640 \
    --cache datastore/weather

read -p "Edit Data Garrison station metadata and press [enter] to continue..."

ruby $SCRIPT put metadata \
    --provider data_garrison \
    --station_id 300234065673960 \
    --user_id 300234063581640 \
    --cache datastore/weather \
    --destination $DESTINATION

ruby $SCRIPT get observations \
    --provider data_garrison \
    --station_id 300234065673960 \
    --user_id 300234063581640 \
    --cache datastore/weather

ruby $SCRIPT put observations \
    --provider data_garrison \
    --station_id 300234065673960 \
    --user_id 300234063581640 \
    --cache datastore/weather \
    --date $INTERVAL \
    --destination $DESTINATION

# Campbell Scientific Test Run
ruby $SCRIPT get metadata \
    --provider campbell_scientific \
    --station_id 606830 \
    --data_url "http://dataservices.campbellsci.ca/sbd/606830/data/CBAY_MET_1HR.dat" \
    --cache datastore/weather

read -p "Edit Campbell Scientific station metadata and press [enter] to continue..."

ruby $SCRIPT put metadata \
    --provider campbell_scientific \
    --station_id 606830 \
    --cache datastore/weather \
    --destination $DESTINATION \
    --blocked LdnCo_Avg,Ux_Avg,Uy_Avg,Uz_Avg,CO2_op_Avg,H2O_op_Avg,Pfast_cp_Avg,xco2_cp_Avg,xh2o_cp_Avg,mfc_Avg

ruby $SCRIPT get observations \
    --provider campbell_scientific \
    --station_id 606830 \
    --cache datastore/weather

ruby $SCRIPT put observations \
    --provider campbell_scientific \
    --station_id 606830 \
    --cache datastore/weather \
    --date $INTERVAL \
    --destination $DESTINATION \
    --blocked LdnCo_Avg,Ux_Avg,Uy_Avg,Uz_Avg,CO2_op_Avg,H2O_op_Avg,Pfast_cp_Avg,xco2_cp_Avg,xh2o_cp_Avg,mfc_Avg
