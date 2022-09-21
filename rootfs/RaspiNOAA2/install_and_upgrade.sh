#!/bin/bash

# these don't work when running from Dockerfile (and arent needed!)
# RED=$(tput setaf 1)
# GREEN=$(tput setaf 2)
# YELLOW=$(tput setaf 3)
# BLUE=$(tput setaf 4)
# BOLD=$(tput bold)
# RESET=$(tput sgr0)

export NOAA_HOME="/RaspiNOAA2"

echo "Home directory is $NOAA_HOME"

die() {
  >&2 echo "${RED}Error: $1${RESET}" && exit 1
}

log_running() {
  echo " ${YELLOW}* $1${RESET}"
}

log_done() {
  echo " ${GREEN}✓ $1${RESET}"
}

log_finished() {
  echo " ${GREEN}$1${RESET}"
}

# run as a normal user
#if [ $EUID -eq 0 ]; then
#  die "Please run this script as the pi user (not as root)"
#fi

# verify the repo exists as expected in the home directory
# if [ ! -e "$NOAA_HOME/raspberry-noaa-v2" ]; then
#   die "Please clone https://github.com/jekhokie/raspberry-noaa-v2 to your home directory"
# fi
#
# check if this is a new install or an upgrade based on modprobe settings
# which is likey a safe way to tell if the user has already installed
# tools and rebooted
install_type='install'

if [ -f /etc/modprobe.d/rtlsdr.conf ]; then
  install_type='upgrade'
fi

log_running "Checking for python3-pip..."
dpkg -l python3-pip >/dev/null 2>&1
if [ $? -eq 0 ]; then
  log_done "  python3-pip already installed!"
else
  log_running "  python3-pip not yet installed - installing..."
  apt-get -y install python3-pip
  if [ $? -eq 0 ]; then
    log_done "    python3-pip successfully installed!"
  else
    die "    Could not install python3-pip - please check the logs above"
  fi
fi

log_running "Installing Python dependencies..."
python3 -m pip install -r $NOAA_HOME/requirements.txt
if [ $? -eq 0 ]; then
  log_done "  Successfully aligned required Python packages!"
else
  die "  Could not install dependent Python packages - please check the logs above"
fi



log_running "Checking configuration files..."
python3 scripts/tools/validate_yaml.py config/settings.yml config/settings_schema.json
if [ $? -eq 0 ]; then
  log_done "  Config check complete!"
else
  die "  Please update your config/settings.yml file to accommodate the above errors"
fi

# install ansible
which ansible-playbook 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  log_running "Updating and installing Ansible..."
  apt update -yq
  apt install -yq ansible

  if [ $? -eq 0 ]; then
    log_done "  Ansible install complete!"
  else
    die "  Could not install Ansible - please inspect the logs above"
  fi
fi

# make sure that web_baseurl is of the correct format
web_baseurl="$(grep -e "^\s*web_baseurl:" config/settings.yml | awk '{print $2}')"
# if [[ "$web_baseurl" != "" ]] && [[ "$web_baseurl" != "false" ]] && [[ "${web_baseurl: -1}" != "/" ]]
# then
#     sed -i 's|\(^\s*web_baseurl:\s*.*\)\s*.*$|\1/|g' config/settings.yml
# fi
if [[ "${web_baseurl,,}" == "false" ]]
then
    sed -i "s|\(^\s*web_baseurl:\).*$|\1 ''|g" config/settings.yml
fi

log_running "Checking for configuration settings..."
if [ -f config/settings.yml ]; then
  log_done "  Settings file ready!"
else
  die "  No settings file detected - please copy config/settings.yml.sample to config/settings.yml and edit for your environment"
fi

log_running "Running Ansible to install and/or update your raspberry-noaa-v2..."
ansible-playbook -i ansible/hosts --extra-vars "@config/settings.yml" ansible/site.yml
if [ $? -eq 0 ]; then
  log_done "  Ansible apply complete!"
else
  die "  Something failed with the install - please inspect the logs above"
fi

# source some env vars
source "$NOAA_HOME/.noaa-v2.conf"

# TLE data files
# NOTE: This should be DRY-ed up with the scripts/schedule.sh script
WEATHER_TXT="${NOAA_HOME}/tmp/weather.txt"
AMATEUR_TXT="${NOAA_HOME}/tmp/amateur.txt"
TLE_OUTPUT="${NOAA_HOME}/tmp/orbit.tle"

# run database migrations
log_running "Updating database schema with any changes..."
$NOAA_HOME/db_migrations/update_database.sh
if [ $? -eq 0 ]; then
  log_done "  Database schema updated!"
else
  die "  Something failed with database update - please inspect the logs above"
fi

# Make sure that the NGINX rewriting rules are set if there is a WEBDIR variable:

# web_directory="$(grep -e "^\s*web_directory:" config/settings.yml | awk '{print $2}')"
# if [[ "$web_directory" != "" ]]
# then
#     sed -i 's/###WEBDIR###/'"$web_directory"'/g' /etc/nginx/sites-available/default
#     sed -i 's/###rewrite/rewrite/g' /etc/nginx/sites-available/default
#     $NOAA_HOME/scripts/reload_nginx.sh
# fi

# update all web content and permissions
log_running "Updating web content..."
(
  find $WEB_HOME/ -mindepth 1 -type d -name "Config" -prune -o -print | xargs rm -rf &&
  cp -r $NOAA_HOME/webpanel/* $WEB_HOME/ &&
  chown -R root:www-data $WEB_HOME/ &&
  composer install -d $WEB_HOME/
) || die "  Something went wrong updating web content - please inspect the logs above"

# run a schedule of passes (as opposed to waiting until cron kicks in the evening)
log_running "Scheduling passes for imagery..."
if [ ! -f $WEATHER_TXT ] || [ ! -f $AMATEUR_TXT ] || [ ! -f $TLE_OUTPUT ]; then
  log_running "Scheduling with new TLE downloaded data..."
  ./scripts/schedule.sh -t
else
  log_running "Scheduling with existing TLE data (not downloading new)..."
  ./scripts/schedule.sh
fi
log_running "Passes scheduled!"

# remove any SDR drivers if they'd incidentally should be present
rmmod rtl2832_sdr >/dev/null 2>&1
rmmod dvb_usb_rtl28xxu >/dev/null 2>&1
rmmod rtl2832 >/dev/null 2>&1
rmmod rtl8xxxu >/dev/null 2>&1
rmmod rtl2838 >/dev/null 2>&1

echo ""
echo "-------------------------------------------------------------------------------"
log_finished "CONGRATULATIONS!"
echo ""
log_finished "raspberry-noaa-v2 has been successfully installed/upgraded!"
echo ""
log_finished "You can view the webpanel updates by visiting the URL(s) listed in the"
log_finished "'output web server url' and 'output web server tls url' play outputs above."
echo "-------------------------------------------------------------------------------"
echo ""
