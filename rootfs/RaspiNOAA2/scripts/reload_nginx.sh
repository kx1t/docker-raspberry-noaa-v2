#!/usr/bin/with-contenv bash
#shellcheck shell=bash

APPNAME="$(hostname)/reload_nginx"

set -a

if [[ -f /run/nginx/pid ]]
then
    echo "[$(date)][$APPNAME] Reloading NGINX ..."
    kill -HUP "$(cat /run/nginx/pid)"
else
    echo "[$(date)][$APPNAME] NGINX is not (yet) running. Skipping Reload!"
fi
