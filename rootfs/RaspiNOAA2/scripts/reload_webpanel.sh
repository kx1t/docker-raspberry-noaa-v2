#!/usr/bin/with-contenv bash
#shellcheck shell=bash

APPNAME="$(hostname)/reload_nginx"

# import common lib and settings
source "$NOAA_HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"

set -a
(
  find $WEB_HOME/ -mindepth 1 -type d -name "Config" -prune -o -print | xargs rm -rf &&
  cp -r $NOAA_HOME/webpanel/* $WEB_HOME/ &&
  chown -R root:www-data $WEB_HOME/ &&
  composer install -d $WEB_HOME/
) || echo "[$(date)][$APPNAME] Something went wrong updating web content - please inspect the logs above"
