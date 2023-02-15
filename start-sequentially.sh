#!/bin/bash
# Requirements:
# * https://github.com/kislyuk/yq

set -e

COMPOSE_FILE="docker-compose.get-and-put-metadata.yaml"

yq -r '.services | keys | .[]' "${COMPOSE_FILE}" | \
while read service; do
    docker-compose -f "${COMPOSE_FILE}" up "$service"
done