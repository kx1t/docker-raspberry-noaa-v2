#!/bin/bash
#shellcheck shell=bash disable=SC2154

settingsfile="$NOAA_HOME/config/settings.yml"

# import common lib and settings
[[ -f "$NOAA_HOME"/.noaa-v2.conf ]] && source "$NOAA_HOME/.noaa-v2.conf" || source "$HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"


LOG "Converting SDR Serials to Device IDs ..." "INFO"


function setvalue () {
    # This function writes values to the settings file
    # Example: setvalue "latitude" "42.41234"
    local param
    local value
    param="$1"; param="${param,,}"
    value="$2"

    [[ -z "$value" ]] && value="\'\'"

	sed -i "s~\(^\s*${param}:\s*\).*~\1${value}~" "$settingsfile"
}

# If xxx_sdr_device_serial is defined, figure out what the device ID is that corresponds to the serial number and replace xxx_sdr_device_id with it
# Figure out for which sats "xxx_sdr_device_serial" is defined:
readarray -t sats <<< "$(sed -n "s/^\s*\([A-Za-z0-9_-]*\)_sdr_device_serial:.*$/\1/p" "$settingsfile")"

# read serial numbers into an array
readarray -t devices <<< "$(timeout 1 rtl_test 2>&1)"
if [[ "${devices[0]:0:3}" == "No " ]]
then
    LOG "EMERGENCY - No SDR devices found!" "ERROR"
    LOG "Please check your setup and restart this script!" "ERROR"
    exit 1
fi

devices_count="$(awk '{print $2}' <<< "${devices[0]}")"

# read the device serial names into an associative array with as index the device_id:
declare -A device_serial
for (( n=1; n<=$devices_count; n++ ))
do
    device_serial+=(["$(sed 's/^\s*\([0-9]*\).*/\1/g' <<< "${devices[n]}")"]="$(sed 's/^\s*[0-9]*.*, SN: \(.*\)/\1/g' <<< "${devices[n]}")")
done

# Now consider these for each of the satellites and replace the device_id in setting.yml accordingly:
for sat in "${sats[@]}"
do
    satserialparam="${sat}_sdr_device_serial"
    satidparam="${sat}_sdr_device_id"
    if [[ -n "${!satserialparam}" ]]
    then
        for i in "${!device_serial[@]}"
        do
            if [[ "${!satserialparam}" == "${device_serial[$i]}" ]]
            then
                LOG "Match: ${device_serial[$i]} --> device_id ${i} for ${satidparam}" "INFO"
                setvalue "${satidparam}" "${i}"
                break
            fi
        done
    fi
done
