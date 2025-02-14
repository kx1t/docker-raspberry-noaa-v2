#!/bin/bash
# shellcheck shell=bash disable=SC2155
#
# Purpose: Receive and process Meteor-M 2 captures.
#
# Input parameters:
#   1. Name of satellite "METEOR-M 2"
#   2. Filename of image outputs
#   3. TLE file location
#   4. Duration of capture (seconds)
#   5. Max angle elevation for satellite
#   6. Direction of pass
#   7. Side of pass (W=West, E=East) relative to base station
#
# Example:
#   ./receive_meteor.sh "METEOR-M 2" METEOR-M220210205-192623 1612571183 922 39 Northbound W

# needed to ensure that we get an error if any command in a pipe fails:
set -o pipefail

# time keeping
TIMER_START=$(date '+%s')

# import common lib and settings
source "$NOAA_HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"
capture_start=$START_DATE

# input params
export SAT_NAME=$1
export FILENAME_BASE=$2
export TLE_FILE=$3
export EPOCH_START=$4
export CAPTURE_TIME=$5
export SAT_MAX_ELEVATION=$6
export PASS_DIRECTION=$7
export PASS_SIDE=$8

# export some variables for use in the annotation - note that we do not
# want to export all of .noaa-v2.conf because it contains sensitive info
export GAIN=$METEOR_M2_GAIN
export SUN_MIN_ELEV=$METEOR_M2_SUN_MIN_ELEV
export SDR_DEVICE_ID=$METEOR_M2_SDR_DEVICE_ID
export BIAS_TEE=$METEOR_M2_ENABLE_BIAS_TEE
export FREQ_OFFSET=$METEOR_M2_FREQ_OFFSET
export SAT_MIN_ELEV=$METEOR_M2_SAT_MIN_ELEV

# base directory plus filename_base for re-use
RAMFS_AUDIO_BASE="${RAMFS_AUDIO}/${FILENAME_BASE}"
AUDIO_FILE_BASE="${METEOR_AUDIO_OUTPUT}/${FILENAME_BASE}"
IMAGE_FILE_BASE="${IMAGE_OUTPUT}/${FILENAME_BASE}"
IMAGE_THUMB_BASE="${IMAGE_OUTPUT}/thumb/${FILENAME_BASE}"

# ---------------------------------------------------------------------------
# always kill running captures for NOAA in favor of capture
# for Meteor, no matter which receive method is being used, in order
# to avoid resource contention and/or signal interference
# First check for rtl_fm mode active instances
if pgrep "rtl_fm" >/dev/null 2>&1; then
    log "Killing existing rtl_fm capture instance in favor of the current METEOR capture run" "INFO"
    pkill -9 -f rtl_fm
fi
# then for gnuradio mode active instances
if pgrep -f "rtlsdr_noaa_apt_rx.py" >/dev/null 2>&1; then
    log "Killing existing gnuradio capture instance in favor of the current METEOR capture run" "INFO"
    pkill -9 -f rtlsdr_noaa_apt_rx.py
fi


# ---------------------------------------------------------------------------
# check if there is enough free memory to store pass on RAM
# check if /run is mounted - if it's not, then there's no actual TMPFS memory

if ! FREE_MEMORY="$(set -o pipefail && df -BM | grep -E '/run$' 2>/dev/null | awk '{print $4}')"; then
    FREE_MEMORY=0
else
    # remove the "M" at the end of the string:
    FREE_MEMORY="${FREE_MEMORY:: -1}"
fi
if (( FREE_MEMORY == 0 )); then
    log "No TMPFS is mounted; capturing to disk" "INFO"
    RAMFS_AUDIO_BASE="${AUDIO_FILE_BASE}"
    in_mem=false
elif [ "$FREE_MEMORY" -lt $METEOR_M2_MEMORY_THRESHOLD ]; then
    log "Not enough space to store a Meteor pass on TMPFS; capturing to disk" "INFO"
    log "Free : ${FREE_MEMORY} ; Required : ${METEOR_M2_MEMORY_THRESHOLD}" "INFO"
    RAMFS_AUDIO_BASE="${AUDIO_FILE_BASE}"
    in_mem=false
else
    log "The system has enough space to store a Meteor pass on TMPFS" "INFO"
    log "Free : ${FREE_MEMORY} ; Required : ${METEOR_M2_MEMORY_THRESHOLD}" "INFO"
    in_mem=true
fi

# ---------------------------------------------------------------------------
# Now set a bunch of parameters:

FLIP=""
log "Direction $PASS_DIRECTION" "INFO"
if [ "$PASS_DIRECTION" == "Northbound" ] && [ "$FLIP_METEOR_IMG" == "true" ]; then
    log "I'll flip this image pass because FLIP_METEOR_IMG is set to true and PASS_DIRECTION is Northbound" "INFO"
    FLIP="-rotate 180"
fi

# pass start timestamp and sun elevation
PASS_START=$(expr "$EPOCH_START" + 90)
export SUN_ELEV="$(python3 "$SCRIPTS_DIR"/tools/sun.py "$PASS_START")"

# determine if pass is in daylight
daylight=0
if [ "${SUN_ELEV}" -gt "${SUN_MIN_ELEV}" ]; then daylight=1; fi

# determine if auto-gain is set - handles "0" and "0.0" floats
gain=$GAIN
if [ "$(echo "$GAIN==0"|bc)" -eq 1 ]; then
    gain='Automatic'
fi

# create push annotation string (annotation in the email subject, discord text, etc.)
# note this is NOT the annotation on the image, which is driven by the config/annotation/annotation.html.j2 file
push_annotation=""
if [ "${GROUND_STATION_LOCATION}" != "" ]; then
    push_annotation="Ground Station: ${GROUND_STATION_LOCATION}\n"
fi
if [ "${ANTENNA_INFORMATION}" != "" ]; then
    push_annotation="Antenna: ${ANTENNA_INFORMATION}\n"
fi
push_annotation="${push_annotation}${SAT_NAME} ${capture_start}"
push_annotation="${push_annotation} Max Elev: ${SAT_MAX_ELEVATION}° ${PASS_SIDE}"
push_annotation="${push_annotation} Sun Elevation: ${SUN_ELEV}°"
push_annotation="${push_annotation} Gain: ${gain}"
push_annotation="${push_annotation} | ${PASS_DIRECTION}"

push_file_list=""
spectrogram=0
polar_az_el=0
polar_direction=0

# ---------------------------------------------------------------------------
# Perform audio capture:

log "Starting $METEOR_RECEIVER record for $CAPTURE_TIME secs (=until $(date -d "+ ${CAPTURE_TIME} seconds"))" "INFO"
if [ "$METEOR_RECEIVER" == "rtl_fm" ]
then
    AUDIO_FILE="${RAMFS_AUDIO_BASE}.wav"
    ${AUDIO_PROC_DIR}/meteor_record_rtl_fm.sh $CAPTURE_TIME "${AUDIO_FILE}" >> "${NOAA_LOG}" 2>&1
elif [ "$METEOR_RECEIVER" == "gnuradio" ]
then
    AUDIO_FILE="${RAMFS_AUDIO_BASE}.s"
    ${AUDIO_PROC_DIR}/meteor_record_gnuradio.sh $CAPTURE_TIME "${AUDIO_FILE}" >> "${NOAA_LOG}" 2>&1
else
    log "Receiver type '$METEOR_RECEIVER' not valid - aborting capture run" "ERROR"
    exit 1
fi

# ---------------------------------------------------------------------------
# QPSK demodulation and creation of spectrogram:

log "Demodulation in progress (QPSK)" "INFO"
qpsk_file="/tmp/meteor/${FILENAME_BASE}.qpsk"
if ! ${AUDIO_PROC_DIR}/meteor_demodulate_qpsk.sh "${AUDIO_FILE}" "${qpsk_file}" >> "${NOAA_LOG}" 2>&1
then
    echo "Couldn't decode any data. Exiting..." >> "${NOAA_LOG}"
    exit 1
fi


if [[ "${PRODUCE_SPECTROGRAM}" == "true" ]]; then
    log "Producing spectrogram" "INFO"
    spectrogram=1
    spectro_text="${capture_start} @ ${SAT_MAX_ELEVATION}°"
    ${IMAGE_PROC_DIR}/spectrogram.sh "${AUDIO_FILE}" "${IMAGE_FILE_BASE}-spectrogram.png" "${SAT_NAME}" "${spectro_text}" >> "${NOAA_LOG}" 2>&1    #Bilo je ${AUDIO_FILE_BASE}.wav
    ${IMAGE_PROC_DIR}/thumbnail.sh 300 "${IMAGE_FILE_BASE}-spectrogram.png" "${IMAGE_THUMB_BASE}-spectrogram.png" >> "${NOAA_LOG}" 2>&1
fi

# ---------------------------------------------------------------------------
# Delete audio or save it to (more) permanent storage:
if [ "$DELETE_AUDIO" = true ]; then
    log "Deleting audio files" "INFO"
    rm -f "${AUDIO_FILE}"
else
    if [ "$in_mem" == "true" ]; then
        log "Moving audio file to permanent storage (${AUDIO_FILE_BASE}.${AUDIO_FILE##*.})" "INFO"
        mv -f "${AUDIO_FILE}" "${AUDIO_FILE_BASE}.${AUDIO_FILE##*.}"
    fi
fi

# ---------------------------------------------------------------------------
# Produce polar plots:
if [[ "${PRODUCE_POLAR_AZ_EL}" == "true" ]]; then
    log "Producing polar graph of azimuth and elevation for pass" "INFO"
    polar_az_el=1
    epoch_end=$((EPOCH_START + CAPTURE_TIME))
    ${IMAGE_PROC_DIR}/polar_plot.py "${SAT_NAME}" \
    "${TLE_FILE}" \
    $EPOCH_START \
    $epoch_end \
    $LAT \
    $LON \
    $SAT_MIN_ELEV \
    $PASS_DIRECTION \
    "${IMAGE_FILE_BASE}-polar-azel.jpg" \
    "azel"
    ${IMAGE_PROC_DIR}/thumbnail.sh 300 "${IMAGE_FILE_BASE}-polar-azel.jpg" "${IMAGE_THUMB_BASE}-polar-azel.jpg"
fi

polar_direction=0
if [[ "${PRODUCE_POLAR_DIRECTION}" == "true" ]]; then
    log "Producing polar graph of direction for pass" "INFO"
    polar_direction=1
    epoch_end=$((EPOCH_START + CAPTURE_TIME))
    ${IMAGE_PROC_DIR}/polar_plot.py "${SAT_NAME}" \
    "${TLE_FILE}" \
    $EPOCH_START \
    $epoch_end \
    $LAT \
    $LON \
    $SAT_MIN_ELEV \
    $PASS_DIRECTION \
    "${IMAGE_FILE_BASE}-polar-direction.png" \
    "direction"
    ${IMAGE_PROC_DIR}/thumbnail.sh 300 "${IMAGE_FILE_BASE}-polar-direction.png" "${IMAGE_THUMB_BASE}-polar-direction.png"
fi

rm -f *.gcp *.bmp 2>/dev/null

for i in spread_*.jpg
do
    $CONVERT -quality 100 $FLIP "$i" "$i" >> "${NOAA_LOG}" 2>&1
done

# ---------------------------------------------------------------------------
# Annotate images and produce thumbnails:

log "Annotating images and creating thumbnails" "INFO"
counter=1
for i in *.jpg
do
    ${IMAGE_PROC_DIR}/meteor_normalize_annotate.sh "$i" "$i" 100 >> "${NOAA_LOG}" 2>&1
    ${IMAGE_PROC_DIR}/thumbnail.sh 300 "$i" "${i%.jpg}-thumb-122-rectified.jpg" >> "${NOAA_LOG}" 2>&1
    mv "$i" "${IMAGE_FILE_BASE}-${counter}-122-rectified.jpg"
    mv "${i%.jpg}-thumb-122-rectified.jpg" "${IMAGE_THUMB_BASE}-${counter}-122-rectified.jpg"
    push_file_list="$push_file_list ${IMAGE_FILE_BASE}-${counter}-122-rectified.jpg "
    ((counter++))
done
counter=1

# check if we got an image, and post-process if so
if [ -f "${IMAGE_FILE_BASE}-1-122-rectified.jpg" ]; then
    log "I got a successful post-processed image" "INFO"

    # insert or replace in case there was already an insert due to the spectrogram creation
    $SQLITE3 $DB_FILE "INSERT OR REPLACE INTO decoded_passes (pass_start, file_path, daylight_pass, sat_type, has_spectrogram, has_polar_az_el, has_polar_direction, gain) \
    VALUES ($EPOCH_START, \"$FILENAME_BASE\", $daylight, 0, $spectrogram, $polar_az_el, $polar_direction, $GAIN);"

    pass_id=$($SQLITE3 $DB_FILE "SELECT id FROM decoded_passes ORDER BY id DESC LIMIT 1;")
    $SQLITE3 $DB_FILE "UPDATE predict_passes \
    SET is_active = 0 \
    WHERE (predict_passes.pass_start) \
    IN ( \
    SELECT predict_passes.pass_start \
    FROM predict_passes \
    INNER JOIN decoded_passes \
    ON predict_passes.pass_start = decoded_passes.pass_start \
    WHERE decoded_passes.id = $pass_id \
    );"
else
    log "Did not get a successful ${IMAGE_FILE_BASE}-1-122-rectified.jpg image - stopping processing" "ERROR"
    exit 1
fi

# ---------------------------------------------------------------------------
# Finally, push to a bunch of notification mechanisms if enabled:

# handle Slack pushing if enabled
if [ "${ENABLE_SLACK_PUSH}" == "true" ]; then
    slack_push_annotation=""
    if [ "${GROUND_STATION_LOCATION}" != "" ]; then
        slack_push_annotation="Ground Station: ${GROUND_STATION_LOCATION}\n "
    fi
    slack_push_annotation="${slack_push_annotation}${SAT_NAME} ${capture_start}\n"
    slack_push_annotation="${slack_push_annotation} Max Elev: ${SAT_MAX_ELEVATION}° ${PASS_SIDE}\n"
    slack_push_annotation="${slack_push_annotation} Sun Elevation: ${SUN_ELEV}°\n"
    slack_push_annotation="${slack_push_annotation} Gain: ${gain} | ${PASS_DIRECTION}\n"

    pass_id=$($SQLITE3 $DB_FILE "SELECT id FROM decoded_passes ORDER BY id DESC LIMIT 1;")
    slack_push_annotation="${slack_push_annotation} <${SLACK_LINK_URL}?pass_id=${pass_id}>\n";

    ${PUSH_PROC_DIR}/push_slack.sh "${slack_push_annotation}" $push_file_list
fi

# handle twitter pushing if enabled
if [ "${ENABLE_TWITTER_PUSH}" == "true" ]; then
    # create push annotation specific to twitter
    # note this is NOT the annotation on the image, which is driven by the config/annotation/annotation.html.j2 file
    twitter_push_annotation=""
    if [ "${GROUND_STATION_LOCATION}" != "" ]; then
        twitter_push_annotation="Ground Station: ${GROUND_STATION_LOCATION} "
    fi
    twitter_push_annotation="${twitter_push_annotation}${SAT_NAME} ${capture_start}"
    twitter_push_annotation="${twitter_push_annotation} Max Elev: ${SAT_MAX_ELEVATION}° ${PASS_SIDE}"
    twitter_push_annotation="${twitter_push_annotation} Sun Elevation: ${SUN_ELEV}°"
    twitter_push_annotation="${twitter_push_annotation} Gain: ${gain}"
    twitter_push_annotation="${twitter_push_annotation} | ${PASS_DIRECTION}"

    log "Pushing image enhancements to Twitter" "INFO"
    ${PUSH_PROC_DIR}/push_twitter.sh "${twitter_push_annotation}" $push_file_list
fi

# handle matrix pushing if enabled
if [ "${ENABLE_MATRIX_PUSH}" == "true" ]; then
    # create push annotation specific to matrix
    # note this is NOT the annotation on the image, which is driven by the config/annotation/annotation.html.j2 file
    matrix_push_annotation=""
    if [ "${GROUND_STATION_LOCATION}" != "" ]; then
        matrix_push_annotation="Ground Station: ${GROUND_STATION_LOCATION} "
    fi
    matrix_push_annotation="${matrix_push_annotation}${SAT_NAME} ${capture_start}"
    matrix_push_annotation="${matrix_push_annotation} Max Elev: ${SAT_MAX_ELEVATION}° ${PASS_SIDE}"
    matrix_push_annotation="${matrix_push_annotation} Sun Elevation: ${SUN_ELEV}°"
    matrix_push_annotation="${matrix_push_annotation} Gain: ${gain}"
    matrix_push_annotation="${matrix_push_annotation} | ${PASS_DIRECTION}"

    log "Pushing image enhancements to Matrix" "INFO"
    ${PUSH_PROC_DIR}/push_matrix.sh "${matrix_push_annotation}" $push_file_list
fi

if [ "$ENABLE_EMAIL_PUSH" == "true" ]; then
    log "Emailing images" "INFO"
    if [ -f "${IMAGE_FILE_BASE}-1-122-rectified.jpg" ]; then
        for i in $push_file_list
        do
            ${PUSH_PROC_DIR}/push_email.sh "${EMAIL_PUSH_ADDRESS}" "$i" "${push_annotation}" >> "${NOAA_LOG}" 2>&1
            sleep 2
        done
    fi
fi

if [ "${ENABLE_DISCORD_PUSH}" == "true" ]; then
    log "Pushing images to Discord" "INFO"
    if [ -f "${IMAGE_FILE_BASE}-1-122-rectified.jpg" ]; then
        for i in $push_file_list
        do
            ${PUSH_PROC_DIR}/push_discord.sh "$i" "${push_annotation}" >> "${NOAA_LOG}" 2>&1
            sleep 2
        done
    fi
fi

# ---------------------------------------------------------------------------
# calculate and report total time for capture
TIMER_END=$(date '+%s')
DIFF=$(($TIMER_END - $TIMER_START))
PROC_TIME=$(date -ud "@$DIFF" +'%H:%M.%S')
log "Total processing time: ${PROC_TIME}" "INFO"
