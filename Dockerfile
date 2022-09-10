FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PIP3_PACKAGES=() && \
    KEPT_RUBY_PACKAGES=() && \
#
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(gcc) && \
    TEMP_PACKAGES+=(python3-dev) && \
    TEMP_PACKAGES+=(pkg-config) && \
#

    KEPT_PACKAGES+=(at) && \
    KEPT_PACKAGES+=(ansible) && \
    KEPT_PACKAGES+=(bc) && \
    KEPT_PACKAGES+=(cmake) && \
    KEPT_PACKAGES+=(composer) && \
    KEPT_PACKAGES+=(cron) && \
    KEPT_PACKAGES+=(ffmpeg) && \
    KEPT_PACKAGES+=(gmic) && \
    KEPT_PACKAGES+=(gnuradio) && \
    KEPT_PACKAGES+=(gr-osmosdr) && \
    KEPT_PACKAGES+=(imagemagick) && \
    KEPT_PACKAGES+=(jq) && \
    KEPT_PACKAGES+=(libatlas-base-dev) && \
    KEPT_PACKAGES+=(libgfortran5) && \
#     KEPT_PACKAGES+=(libjpeg9) && \
    KEPT_PACKAGES+=(libjpeg-dev) && \
    KEPT_PACKAGES+=(libncurses5-dev) && \
    KEPT_PACKAGES+=(libncursesw5-dev) && \
    KEPT_PACKAGES+=(libsox-fmt-mp3) && \
    KEPT_PACKAGES+=(libusb-1.0-0) && \
    KEPT_PACKAGES+=(libusb-1.0-0-dev) && \
    KEPT_PACKAGES+=(libxft-dev) && \
    KEPT_PACKAGES+=(libxft2) && \
    KEPT_PACKAGES+=(nginx) && \
    KEPT_PACKAGES+=(php7.4-fpm) && \
    KEPT_PACKAGES+=(php7.4-mbstring) && \
    KEPT_PACKAGES+=(php7.4-sqlite3) && \
    KEPT_PACKAGES+=(gpredict) && \
    KEPT_PACKAGES+=(python3-pip) && \
    KEPT_PACKAGES+=(python-setuptools) && \
    KEPT_PACKAGES+=(socat) && \
    KEPT_PACKAGES+=(sox) && \
    KEPT_PACKAGES+=(sqlite3) && \

# other packages"
    KEPT_PACKAGES+=(unzip) && \
    KEPT_PACKAGES+=(psmisc) && \
    KEPT_PACKAGES+=(jq) && \
    KEPT_PACKAGES+=(iputils-ping) && \
#
#    KEPT_RUBY_PACKAGES+=(twurl) && \
#
# Install all the apt, pip3, and gem (ruby) packages:
    apt-get update -q && \
    apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests ${TEMP_PACKAGES[@]} ${KEPT_PACKAGES[@]} && \
#    gem install twurl && \
#    pip3 install ${KEPT_PIP3_PACKAGES[@]} && \
#
# Do this here while we still have git installed:
    git config --global advice.detachedHead false && \
    echo "main_($(git ls-remote https://github.com/kx1t/docker-planefence HEAD | awk '{ print substr($1,1,7)}'))_$(date +%y-%m-%d-%T%Z)" > /root/.buildtime && \
# Clean up
    echo Uninstalling $TEMP_PACKAGES && \
    apt-get remove -y -q ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y -q && \
    rm -rf \
      /src/* \
      /tmp/* \
      /var/lib/apt/lists/* \
      /.dockerenv \
      /git
#
COPY rootfs/ /
#
#COPY ATTRIBUTION.md /usr/share/planefence/stage/attribution.txt
#
RUN set -x && \
#
#
    /install/install_and_upgrade.sh && \
#
# Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc

#
# No need for SHELL and ENTRYPOINT as those are inherited from the base image
#

EXPOSE 80
