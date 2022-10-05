#!/bin/bash
#shellcheck shell=bash

# (C) Copyright 2022 by kx1t. Licensed under GPLv3.
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

# Convert_to_docker.sh reads an existing non-containerized configuration of RaspiNOAA2 and produces a docker-compose.yml file from it.
# It will also attempt to retain the existing database and saved media files.

APPNAME="convert_to_docker"
SETTINGS_LOCATION="$HOME/config/settings.yml"
MEDIA_LOCATION="/srv"
DB_LOCATION="$HOME/db/panel.db"
CONTAINER_DIR="/opt/raspinoaa2"
DOCKERCOMPOSE_TEMPLATE="https://raw.githubusercontent.com/kx1t/docker-raspberry-noaa-v2/main/docker-compose.yml"
EXCLUDED_SETTINGS=()
EXCLUDED_SETTINGS+=("disable_wifi_power_mgmt")
EXCLUDED_SETTINGS+=("ntp_server")
USER="$(whoami)"
if [[ "$USER" != "root" ]]
then
    SUDO="sudo"
else
    SUDO=""
fi

function setvalue () {
    # This function writes values to the settings file
    # Example: setvalue "latitude" "42.41234"
    local param
    local value
    param="$1"; param="${param,,}"
    value="$2"

    [[ -z "$value" ]] && value="''"

	sed -i "s~\(^\s*- ${param}=\).*~\1${value}~" "$CONTAINER_DIR/docker-compose.yml"
}

echo "[$(date)][$APPNAME] $0 - create a docker-compose.yml file from an existing non-containerized RaspiNOAA2 setup."

# Check the command line args:
argv="$1"
argv="${argv,,}"

if [[ "$argv" == "-?" ]] || [[ "$argv" == "-h" ]]
then
    echo "Usage:"
    echo "$0 -c          (C)onvert an existing non-Docker Raspberry NOAA V2 setup to Docker and run this Docker"
    echo "$0 -d          only generate a (D)ocker-compose.yml file that can be used on a different machine"
    echo "$0 -? or -h    Show this help text"
    exit 0
elif [[ "$argv" != "-c" ]] && [[ "$argv" != "-d" ]]
then
    echo "You need to specify either -c or -d, or you can ask help using $0 -?"
    exit 1
fi

if [[ "$argv" == "-d" ]]
then
    MEDIA_LOCATION=""
    DB_LOCATION=""
    CONTAINER_DIR="."
fi

# Check if a number of prerequisites are available and resolve if not:
if [[ "$argv" == "-c" ]] && ! which docker >/dev/null 2>&1
then
    echo "[$(date)][$APPNAME] Docker is not yet installed on this machine. We suggest that you go here and use the \"docker-install\" script to install and configure it."
    echo "[$(date)][$APPNAME] https://githib.com/sdr-enthusiasts/docker-install"
    echo ""
    exit 1
fi

if [[ ! -f $SETTINGS_LOCATION ]]
then
    echo "[$(date)][$APPNAME] Cannot find an existing settings.xml file at $SETTINGS_LOCATION"
    read -p "[$(date)][$APPNAME] Please enter the location of your settings.yml file: " SETTINGS_LOCATION
    [[ "${SETTINGS_LOCATION: -12}" != "settings.yml" ]] && SETTINGS_LOCATION="$SETTINGS_LOCATION/settings.yml"
    if [[ ! -f $SETTINGS_LOCATION ]]
    then
        echo "[$(date)][$APPNAME] Still cannot find your settings.yml file at $SETTINGS_LOCATION. Please check and run this script again."
        exit 1
    fi
fi

if [[ "$argv" == "-c" ]] && [[ ! -d $MEDIA_LOCATION ]]
then
    echo "[$(date)][$APPNAME] Cannot find an existing media directory at $MEDIA_LOCATION"
    read -p "[$(date)][$APPNAME] Please enter the location of your media directory. If you don't have any saved media, press ENTER to leave it blank: " MEDIA_LOCATION
    if [[ ! -d $MEDIA_LOCATION ]]
    then
        echo "[$(date)][$APPNAME] Still cannot find your media directory at $MEDIA_LOCATION. Will not include those files."
        MEDIA_LOCATION=""
    fi
fi

if [[ "$argv" == "-c" ]] && [[ ! -f $DB_LOCATION ]]
then
    echo "[$(date)][$APPNAME] Cannot find an existing database at $DB_LOCATION"
    read -p "[$(date)][$APPNAME] Please enter the location of your panel.db database. If you don't have any saved media, press ENTER to leave it blank: " DB_LOCATION
    if [[ ! -f $DB_LOCATION ]]
    then
        echo "[$(date)][$APPNAME] Still cannot find your database at $DB_LOCATION. Will not include those files."
        DB_LOCATION=""
    fi
fi

# show setup info and allow user to abort if they don't like it:
echo "[$(date)][$APPNAME] Starting the creation of a docker-compose.yml file using the following parameters:"
echo "[$(date)][$APPNAME] Target location: $CONTAINER_DIR/docker-compose.yml"
echo "[$(date)][$APPNAME] Reading settings parameters from: $SETTINGS_LOCATION"
[[ -n "$MEDIA_LOCATION" ]] && echo "[$(date)][$APPNAME] Including existing media files from: $MEDIA_LOCATION" || echo "[$(date)][$APPNAME] Not including any existing media files"
[[ -n "$DB_LOCATION" ]] && echo "[$(date)][$APPNAME] Including existing database from: $DB_LOCATION" || echo "[$(date)][$APPNAME] Not including your existing database file"

read -s -n 1 -p "[$(date)][$APPNAME] Press any key to start or CTRL-c to abort..."

# start prepping the target area:
$SUDO mkdir -p "$CONTAINER_DIR"
$SUDO chmod a+rwx "$CONTAINER_DIR"
if [[ -f "$CONTAINER_DIR/docker-compose.yml" ]]
then
    echo "Found an existing file at $CONTAINER_DIR/docker-compose.yml. This file will be backed up as $CONTAINER_DIR/docker-compose-backup.yml"
    cp -f "$CONTAINER_DIR/docker-compose.yml" "$CONTAINER_DIR/docker-compose-backup.yml"
    $SUDO rm -f "$CONTAINER_DIR/docker-compose.yml"
fi

# get a template docker-compose.yml file:
if ! curl -Ls -o "$CONTAINER_DIR/docker-compose.yml" "$DOCKERCOMPOSE_TEMPLATE"
then
    echo "Couldn't get a template docker-compose file. Aborting..."
    exit 1
fi

# Get all variables from the settings file and iterate through them:
for variable in $(sed -n 's|^\s*\([A-Za-z0-9\_\-]*\):.*|\1|p' "$SETTINGS_LOCATION")
do
    if [[ "${variable}" != "" ]]
    then
        value="$(sed -n 's|^\s*'"${variable}"'\s*:\s*\(.*\)$|\1|p' "$SETTINGS_LOCATION")"
        if grep -e '^\s*- '"${variable}"'=.*$' "$CONTAINER_DIR/docker-compose.yml" >/dev/null 2>&1
        then
            # the param exists in docker-compose.yml - let's update it
            sed -i "s~\(^\s*- ${variable}=\).*~\1${value}~" "$CONTAINER_DIR/docker-compose.yml"
        else
            # the param doesn't exist in docker-compose.yml Figure out if we need to add it
            #shellcheck disable=SC2076
            if [[ " ${EXCLUDED_SETTINGS[*]} " =~ " ${variable} " ]]
            then
                echo "$variable=$value was excluded -- not needed/desired in Docker environment"
            else
                # Let's add it as the first variable after the environment: tag
                # $firstline will contain the first line after the environment: tag
                firstline="$(sed -n '/\s*environment:/{n;p;q}' "$CONTAINER_DIR/docker-compose.yml" )"
                # strip $firstline from anything before the actual "name=value part:
                firstline="$(sed -n 's|^[ -]*\(.*\)$|\1|p' <<< "$firstline")"
                # if the firstline starts with "#", it wasn't a variable and we'll have to assume there was no "- ":
                [[ "${firstline:0:1}" == "#" ]] && variable="- $variable"
                # now insert the new variable and value before $firstline into the file
                sed -i "s|^\([ -]*\)\($firstline\)$|\1$variable=$value\n\1\2|g" "$CONTAINER_DIR/docker-compose.yml"
            fi
        fi
    fi
done

if [[ "$argv" == "-d" ]]
then
    echo "[$(date)][$APPNAME] Done! Your docker-compose file is available here: $CONTAINER_DIR/docker-compose.yml"
    exit 0
fi

echo "[$(date)][$APPNAME] We now need to start the Docker container for a moment to ensure that the correct mapped volumes are created."
echo "[$(date)][$APPNAME] If this is the very first time you run the Docker Container, it may take a while:"
echo "[$(date)][$APPNAME] Download size is about 600 MB and download/extraction times, even with a high speed internet connection, can vary between"
echo "[$(date)][$APPNAME] 2.5 minutes (on a i7 PC) to upwards of 20 minutes on a Raspberry Pi 3B+."
echo ""

#shellcheck disable=SC2164
pushd "$CONTAINER_DIR" >/dev/null
    docker compose up -d && docker-compose down
#shellcheck disable=SC2164
popd

if [[ -n "$MEDIA_LOCATION" ]]
then
    echo "[$(date)][$APPNAME] Copying previously captured media (images, audio, video) in place..."
    targetdir="$(sed -n 's|^[ -]*\(.*\):.*$|\1|p' <<< "$(grep ":/srv" "$CONTAINER_DIR/docker-compose.yml")")"
    $SUDO chmod a+rwx "$targetdir"
    cp -rf $MEDIA_LOCATION/* "$targetdir"
else
    echo "[$(date)][$APPNAME] Skipping the copying of previously captured media."
fi

if [[ -n "$DB_LOCATION" ]]
then
    echo "[$(date)][$APPNAME] Copying existing database in place..."
    # Get the target directory name:
    targetdir="$(sed -n 's|^[ -]*\(.*\):.*$|\1|p' <<< "$(grep ":/RaspiNOAA2/db" "$CONTAINER_DIR/docker-compose.yml")")"
    $SUDO chmod a+rwx "$targetdir"
    cp -rf $DB_LOCATION/* "$targetdir"
else
    echo "[$(date)][$APPNAME] Skipping the copying of existing database."
fi

echo "[$(date)][$APPNAME] Now we will unload any currently scheduled capture runs, and remove any CRON jobs related to schedule updates."
echo "[$(date)][$APPNAME] If you want to switch back later, make sure to run the \"install_and_upgrade.sh\" script to reinstate them."

# remove the AT queue:
for x in $(atq|awk '{print $1}')
do
    atrm "$x" >/dev/null 2>&1
done

# remove the cron runs of schedule.sh:
crontab -l >/tmp/crontab.tmp
awk '$0!~/schedule.sh/ { print $0 }' /tmp/crontab.tmp >/tmp/crontab.new
crontab /tmp/crontab.new

echo "[$(date)][$APPNAME] Done! Now, you should do the following things:"
echo "[$(date)][$APPNAME] - review $CONTAINER_DIR/docker-compose.yml to make sure it corresponds with what you want"
echo "[$(date)][$APPNAME] - start the container with the following commands:"
echo "[$(date)][$APPNAME]        cd $CONTAINER_DIR"
echo "[$(date)][$APPNAME]        docker-compose up -d"
echo "[$(date)][$APPNAME] - take a look at the Docker Logs while the container starts up with this command:"
echo "[$(date)][$APPNAME]        docker logs -f noaa"
echo "[$(date)][$APPNAME]   (press CTRL-c to stop viewing the logs)"
echo "[$(date)][$APPNAME]   (the container should be fully up and running when you see this in the log: [noaa/php-fpm] php-fpm7.4 is ready )"
echo "[$(date)][$APPNAME] - Once fully up and running, RaspiNOAA2 will be active on this website from your home network:"
echo "[$(date)][$APPNAME]        http://$(hostname -I|awk '{print $1}'):$(sed -n 's|^\s*- \([0-9]*\):80$|\1|p' "$CONTAINER_DIR/docker-compose.yml")"
echo "[$(date)][$APPNAME]"
echo "[$(date)][$APPNAME] - from the $CONTAINER_DIR, you can give the following commands to control the container:"
echo "[$(date)][$APPNAME]        docker-compose pull            # download the latest Docker Container"
echo "[$(date)][$APPNAME]        docker-compose down            # stop the container"
echo "[$(date)][$APPNAME]        docker-compose up -d           # restart the container - it will download the software if it isn't already loaded"
echo "[$(date)][$APPNAME] - Note -- after a reboot of the system, Docker Containers will automatically restart without the need for user intervention."
echo "[$(date)][$APPNAME]"
echo "[$(date)][$APPNAME] - Last - there are a few new variables you can set in docker-compose.yml. These are described in the documentation at"
echo "[$(date)][$APPNAME]   https://github.com/kx1t/docker-raspberyy-noaa-v2."
echo "[$(date)][$APPNAME]"
echo "[$(date)][$APPNAME] Good luck! We're all rooting for you!"
echo "[$(date)][$APPNAME] 73 de kx1t/Ramon"
