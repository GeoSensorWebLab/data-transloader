#!/bin/bash

set -e

# STA_URL ends with an slash!!!
#STA_URL="http://localhost:8080/FROST-Server/v1.0/"
#INSTRUMENT_DETAILS_BASE_URL="https://canwin-datahub.ad.umanitoba.ca/data/instrument_details"

function get-sensor-id() {
    local NAME="$1"
    curl -sG "${STA_URL}Sensors" --data-urlencode "\$filter=name eq '${NAME}'" | jq -r '.value[0]["@iot.id"]'
}

function update-sensors() {
    local STATION_ID="$1"
    local STATION_SENSOR_NAME="$2"
    local INSTRUMENT_DETAILS="$3"
    local METADATA_URL="${INSTRUMENT_DETAILS_BASE_URL}/${INSTRUMENT_DETAILS}"
    declare -A NAMES DESCRIPTIONS

    NAMES["Station ${STATION_ID} Pressure Sensor"]="${STATION_SENSOR_NAME} Barometric Pressure Sensor"
    NAMES["Station ${STATION_ID} PAR Sensor"]="${STATION_SENSOR_NAME} HOBO PAR Sensor"
    NAMES["Station ${STATION_ID} Temperature Sensor"]="${STATION_SENSOR_NAME} HOBO Temperature/Relative Humidity Smart Sensor- Temperature Sensor"
    NAMES["Station ${STATION_ID} RH Sensor"]="${STATION_SENSOR_NAME} HOBO Temperature/Relative Humidity Smart Sensor- Relative Humidity (RH Sensor)"
    NAMES["Station ${STATION_ID} Rain Sensor"]="${STATION_SENSOR_NAME} HOBO Rain Gauge"
    NAMES["Station ${STATION_ID} Wind Speed Sensor"]="${STATION_SENSOR_NAME} R M Young Wind sensor/monitor - Wind Speed Sensor"
    NAMES["Station ${STATION_ID} Wind Direction Sensor"]="${STATION_SENSOR_NAME} R M Young Wind sensor/monitor - Wind direction Sensor"
    NAMES["Station ${STATION_ID} Gust Speed Sensor"]="${STATION_SENSOR_NAME} R M Young Wind sensor/monitor - Gust Speed Sensor"
    NAMES["Station ${STATION_ID} Backup Batteries Sensor"]="${STATION_SENSOR_NAME} Backup Batteries Sensor"

    DESCRIPTIONS["Station ${STATION_ID} Pressure Sensor"]="Pressure measured using a barometer mounted inside the enclosure that houses the air temperature sensor.  It is reported in millibars, where 1000 millibars is the average air pressure at sea level. Changing pressure often indicates a coming change in the weather.  Increasing pressure is associated with clearing skies.  Decreasing pressure is associated with increasing cloudiness, and possibly an approaching storm"
    DESCRIPTIONS["Station ${STATION_ID} PAR Sensor"]="Photosynthetically active radiation (PAR) is a measure of light. It is the intensity of the part of sunlight that plants can use to support new growth, and also the wavelengths of light that our eyes are sensitive to. It is measured on a small white disc that records the sum of light falling directly from the sun plus the light scattered by the sky and clouds. It is reported in a unit called a micro-Einstein."
    DESCRIPTIONS["Station ${STATION_ID} Temperature Sensor"]="We report temperature in the shade, in Centigrade degrees. It is measured using an electronic thermometer shielded from direct sunlight and mounted inside an enclosure with louvered walls to allow free air flow past the sensor."
    DESCRIPTIONS["Station ${STATION_ID} RH Sensor"]="Relative humidity is the amount of water vapour in the air reported as a percentage of the amount that would saturate it at the air temperature. Warmer air can hold more water vapour than cooler air."
    DESCRIPTIONS["Station ${STATION_ID} Rain Sensor"]="Rain is reported in millimetres accumulated every 15 minutes in a gauge set about 1 m above the ground. Rain falling into a 6-inch diameter funnel drips onto one of a pair of “buckets”, mounted on a teeter-totter. When one bucket is filled, the teeter-totter flips, the first bucket is emptied and rain then drips into the other “bucket” until it is filled, and so on. Each flip is equal to 0.2 mm of rain."
    DESCRIPTIONS["Station ${STATION_ID} Wind Speed Sensor"]="Wind speed is measured using a spinning anemometer mounted on the wind vane at the top of the tower, about 3 m above the ground. We report the average speed for every 15 minute period, in kilometres per hour."
    DESCRIPTIONS["Station ${STATION_ID} Wind Direction Sensor"]="Wind direction is measured using a wind vane mounted at the top of the tower.  As we do with wind speed, we report the average direction for every 15 minutes, in compass degrees from true north. It is then converted to a direction."
    DESCRIPTIONS["Station ${STATION_ID} Gust Speed Sensor"]="Wind gusts are the highest wind speed recorded in each 15 minute period, and are also recorded in kilometres per hour."
    DESCRIPTIONS["Station ${STATION_ID} Backup Batteries Sensor"]="This sensor is measuring the voltage from the 12 volt battery that acts as a backup to the solar panels."


    for OLDNAME in "${!NAMES[@]}"; do
        local SENSOR_ID="$(get-sensor-id "${OLDNAME}")"
        local NAME="${NAMES[$OLDNAME]}"
        local DESCRIPTION="${DESCRIPTIONS[${OLDNAME}]}"
        if [ -n "${SENSOR_ID}" -a "${SENSOR_ID}" != "null" ]; then
            if [ -z "${STA_USER}" ] || [ -z "${STA_PASSWORD}" ]; then
                curl -X PATCH \
                    -H "Content-Type: application/json" \
                    "${STA_URL}Sensors(${SENSOR_ID})" \
                    -d "{
                        \"name\": \"${NAME}\",
                        \"description\": \"${DESCRIPTION}\",
                        \"metadata\": \"${METADATA_URL}\"
                    }"
            else
                curl -X PATCH \
                    -u "${STA_USER}:${STA_PASSWORD}" \
                    -H "Content-Type: application/json" \
                    "${STA_URL}Sensors(${SENSOR_ID})" \
                    -d "{
                        \"name\": \"${NAME}\",
                        \"description\": \"${DESCRIPTION}\",
                        \"metadata\": \"${METADATA_URL}\"
                    }"
            fi

        fi
    done
}


#STATION_ID="300534061454190"
#STATION_SENSOR_NAME="Dawson Bay Li Taan Aen Staansyoon"
#INSTRUMENT_DETAILS="dawbay-met-sensors"
#update-sensors "${STATION_ID}" "${STATION_SENSOR_NAME}" "${INSTRUMENT_DETAILS}"

#STATION_ID="300534063017060"
#STATION_SENSOR_NAME="St Laurent Li Taan Aen Staansyoon"
#INSTRUMENT_DETAILS="st-laurent-met-sensors"
#update-sensors "${STATION_ID}" "${STATION_SENSOR_NAME}" "${INSTRUMENT_DETAILS}"

update-sensors "$1" "$2" "$3"
