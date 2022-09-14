#!/usr/bin/with-contenv bash
#
# Purpose: Creates a false colour image from NOAA APT images based on temperature using
#          the HVC colour model. Uses the temperature derived from the sensor 4 image to
#          select the hue and the brightness from the histogram equalised other image to
#          select the value and chroma. The HVC colour model attempts to ensure that different
#          colours at the same value will appear to the eye to be the same brightness
#          and the spacing between colours representing each degree will appear to the eye to
#          be similar. Bright areas are completely unsaturated in this model. The palette
#          used can be changed using the -P option.
#
# Input parameters:
#   1. Map overlap file
#   2. Input .wav file
#   3. Output .jpg file
#
# Example:
#   ./noaa_hvc.sh /path/to/map_overlay.png /path/to/input.wav /path/to/output.jpg

# import common lib and settings
source "$NOAA_HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"

# input params
MAP_OVERLAY=$1
INPUT_WAV=$2
OUTPUT_IMAGE=$3

# calculate any extra args for the processor
extra_args=""
if [ "${NOAA_CROP_TELEMETRY}" == "true" ]; then
  extra_args=${extra_args}" -c"
fi

if [ "${NOAA_CROP_TOPTOBOTTOM}" == "false" ]; then
  extra_args=${extra_args}" -A"
fi

if [ "${NOAA_INTERPOLATE}" == "true" ]; then
  extra_args=${extra_args}" -I"
fi

# produce the output image
$WXTOIMG -o -m "${MAP_OVERLAY}" ${extra_args} -e "HVC" "${INPUT_WAV}" "${OUTPUT_IMAGE}"
