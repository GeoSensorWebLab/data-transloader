#!/bin/bash

set -e

# fail early
STA_URL=${STA_URL:?"Error: STA_URL not set"}

# build the command by quoting addtional parameters
COMMAND="cd $(pwd) && ./docker/cron/cronjob.sh"
for PARAM in "$@"; do 
    COMMAND="$COMMAND ${PARAM@Q}"
done 

# build the crontab
env > /etc/cron.d/transloader-job
echo >> /etc/cron.d/transloader-job
echo "${SCHEDULE:-"@daily"} $(id -un) ${COMMAND} > /proc/\$(cat /var/run/crond.pid)/fd/1 2>/proc/\$(cat /var/run/crond.pid)/fd/2" >> /etc/cron.d/transloader-job

# give over to cron
exec cron -f -L 15