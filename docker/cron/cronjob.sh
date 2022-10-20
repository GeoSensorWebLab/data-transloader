#!/bin/bash

set -ex

STA_URL="${STA_URL:?"Error: STA_URL not set"}"
DATABASE_URL="file://${DATA_DIR}"
INTERVAL="$(date -u -d "${MOVING_WINDOW} ago" "+%Y-%m-%dT%TZ")/$(date -u "+%Y-%m-%dT%TZ")"

if [ "$OVERWRITE_METADATA" = "true" ]; then
    ruby transload get metadata --database_url "${DATABASE_URL}" --overwrite "$@"
fi 

ruby transload put metadata --database_url "${DATABASE_URL}" --destination "${STA_URL}" "$@"
ruby transload get observations --database_url "${DATABASE_URL}" "$@"
ruby transload put observations --database_url "${DATABASE_URL}" --destination "${STA_URL}" --date "${INTERVAL}" "$@"
