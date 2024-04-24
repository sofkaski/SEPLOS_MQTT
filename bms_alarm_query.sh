#!/bin/bash
set -euo pipefail

# Load config parameters
CONFIG_FILE=/home/jyrki/SEPLOS_MQTT/config.ini
MQTTHOST=$(grep "MQTTHOST" "${CONFIG_FILE}" | awk -F "=" '{print $2}')
TOPIC=$(grep "TOPIC" "${CONFIG_FILE}" | awk -F "=" '{print $2}')
MQTTUSER=$(grep "MQTTUSER" "${CONFIG_FILE}" | awk -F "=" '{print $2}')
MQTTPASWD=$(grep "MQTTPASWD" "${CONFIG_FILE}" | awk -F "=" '{print $2}')
TELEPERIOD=$(grep "TELEPERIOD" "${CONFIG_FILE}" | awk -F "=" '{print $2}')
id_prefix=$(grep "id_prefix" "${CONFIG_FILE}" | awk -F "=" '{print $2}')

process_id="$$"
enable_debug_logs=''

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Masks for alarm condition
NO_ALARM=b'0x00'
LOWER_LIMIT_ALARM=b'0x01'
UPPER_LIMIT_ALARM=b'0x02'
OTHER_ALARM=b'0xF0'

# Offsets in the reponse message
declare -A offset
offset[nbr_of_cells]=17
offset[cell_alarms]=19
offset[nbr_of_temperatures]=51
offset[temperature_alarms]=53
offset[current_alarm]=58
offset[battery_voltage_alarm]=60
offset[nbr_of_custom_alarms]=69
offset[custom_alarms]=71



log() {
    local -r priority="${1}"
    local -r message="${2}"

    logger -p local0."${priority}" -t "bms-alarm-query_${process_id}" "${message}"
}

log_info() {
    local -r message="${1}"
    log info "${message}"
}

log_error() {
    local -r message="${1}"
    log err "${message}"
}

log_debug() {
    local -r message="${1}"
    if [ -n "${enable_debug_logs}" ]; then 
        log debug "${message}"
    fi
}

get_nbr_from_response() {
    local -r field="${1}"
    echo $(("0x${query_response:${offset[${field}]}:2}"))
}

get_field_from_response() {
    local -r field="${1}"
    local -r length="${2}"
    echo "${query_response:${offset[${field}]}:${length}}"
}

#log_info 'BMS alarm query started'

query_response=$("${SCRIPT_DIR}"/query_seplos_ha.sh 4401)
if [ "${query_response:0:5}" != '~2000' ]; then
    log_error "Query failed. Got invalid response: ${query_response}"
    echo "Invalid response: ${query_response}" >&2
    exit 1
fi
echo "Query response: ${query_response}"

nbr_of_cells=$(get_nbr_from_response nbr_of_cells)
cell_alarms=$(get_field_from_response cell_alarms $((nbr_of_cells * 2)))
echo "Cell alarms: ${cell_alarms}"
nbr_of_temperatures=$(get_nbr_from_response nbr_of_temperatures)
temperature_alarms=$(get_field_from_response temperature_alarms $((nbr_of_temperatures * 2)))
echo "Temperature alarms: ${temperature_alarms}"
current_alarm=$(get_nbr_from_response current_alarm)
echo "Current alarm: ${current_alarm}"
battery_voltage_alarm=$(get_nbr_from_response battery_voltage_alarm)
echo "Battery voltage alarm: ${battery_voltage_alarm}"
nbr_of_custom_alarms=$(get_nbr_from_response nbr_of_custom_alarms)
custom_alarms=$(get_field_from_response custom_alarms $((nbr_of_custom_alarms * 2)))
echo "Custom alarms: ${custom_alarms}"

#log_info 'BMS alarm query done'


