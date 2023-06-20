#!/bin/bash

set -e
# for debugging
# set -x

STA_URL="${STA_URL:?"Error: STA_URL not set"}"
DATABASE_URL="file://${DATA_DIR}"
INTERVAL="$(date -u -d "${MOVING_WINDOW} ago" "+%Y-%m-%dT%TZ")/$(date -u "+%Y-%m-%dT%TZ")"

if [ "$OVERWRITE_METADATA" = "true" ]; then
    ruby transload get metadata --database_url "${DATABASE_URL}" --overwrite "$@"
    if [ -z "${STA_USER}" ] || [ -z "${STA_PASSWORD}" ]; then
        ruby transload put metadata --database_url "${DATABASE_URL}" --destination "${STA_URL}" "$@"
    else
        ruby transload put metadata --database_url "${DATABASE_URL}" --destination "${STA_URL}" --user "${STA_USER}:${STA_PASSWORD}" "$@"
    fi
fi 

ruby transload get observations --database_url "${DATABASE_URL}" "$@"

if [ -z "${STA_USER}" ] || [ -z "${STA_PASSWORD}" ]; then
    ruby transload put observations --database_url "${DATABASE_URL}" --destination "${STA_URL}" --date "${INTERVAL}" "$@"
else
    ruby transload put observations --database_url "${DATABASE_URL}" --destination "${STA_URL}" --date "${INTERVAL}" --user "${STA_USER}:${STA_PASSWORD}" "$@"
fi
