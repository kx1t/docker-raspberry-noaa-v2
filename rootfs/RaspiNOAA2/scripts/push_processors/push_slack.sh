#!/usr/bin/with-contenv bash

# import common lib and settings
. "$NOAA_HOME/.noaa-v2.conf"
. "$NOAA_HOME/scripts/common.sh"

NAME=${SLACK_PUSH_TO}
URL=${SLACK_PUSH_URL}
TEXT=$1

curl --silent -X POST --data-urlencode "payload={\"channel\": \"@${NAME}\", \"username\": \"webhookbot\", \"text\": \"${TEXT}\", \"icon_emoji\": \":ghost:\"}" "${URL}"
