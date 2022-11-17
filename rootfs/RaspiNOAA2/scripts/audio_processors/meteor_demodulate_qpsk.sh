#!/bin/bash
#
# Purpose: Demodulate Meteor-M 2 audio file in QPSK format.
#
# Input parameters: (note the output.wav is the input to generate the output.qpsk)
#   1. Input .wav file
#   2. Output QPSK file
#
# Example:
#   ./demodulate_meteor_qpsk.sh /path/to/input.qpsk /path/to/output.wav

# import common lib and settings
set -a
source "$NOAA_HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"

# input params
INPUT_WAV=$1
OUTPUT_QPSK=$2


# produce the output image - note QPSK output lists before wav
$METEOR_DEMOD -B -o "${OUTPUT_QPSK}" "${INPUT_WAV}" >> "$NOAA_LOG" 2>&1
# note we switched to DigitElektro's MeteorDemod (https://github.com/Digitelektro/MeteorDemod)
# Also reduced the amount of log messages a bit -- only logged when signal is locked, or at 5/10/15/etc %
# $METEOR_DEMOD -i "${INPUT_WAV}" -o "${OUTPUT_QPSK}" -t "${TLE_OUTPUT}" -f jpg 2> "${NOAA_LOG}" \
#     | stdbuf -oL tr '\r' '\n' | grep "Progress: [0-9]*[05].00\|isLocked: 1\|synch:\|Decoded\|received" >> "${NOAA_LOG}"
#
# if ! grep "No data received" <<< "$(tail "${NOAA_LOG}")"
# then
#     exit 1
# fi
