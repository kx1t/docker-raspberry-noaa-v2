FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

ARG TARGETARCH
ENV NOAA_HOME="/RaspiNOAA2"
ARG BRANCH="meteordemod_staging"

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PIP3_PACKAGES=() && \
    KEPT_RUBY_PACKAGES=() && \
    #
    KEPT_PACKAGES+=(ansible) && \
    KEPT_PACKAGES+=(at) && \
    KEPT_PACKAGES+=(bc) && \
    KEPT_PACKAGES+=(composer) && \
#    KEPT_PACKAGES+=(cron) && \
    KEPT_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ffmpeg) && \
    KEPT_PACKAGES+=(gfortran) && \
    KEPT_PACKAGES+=(gmic) && \
    KEPT_PACKAGES+=(gnuradio) && \
    KEPT_PACKAGES+=(gr-osmosdr) && \
    KEPT_PACKAGES+=(imagemagick) && \
    KEPT_PACKAGES+=(kmod) && \
    KEPT_PACKAGES+=(libasound2-dev) && \
    KEPT_PACKAGES+=(libatlas-base-dev) && \
    KEPT_PACKAGES+=(libgfortran5) && \
    KEPT_PACKAGES+=(libgtk-3-0) && \
    KEPT_PACKAGES+=(libgdk-pixbuf2.0-0) && \
    KEPT_PACKAGES+=(libjpeg-dev) && \
    KEPT_PACKAGES+=(liblapacke-dev) && \
    KEPT_PACKAGES+=(libncurses5-dev) && \
    KEPT_PACKAGES+=(libncursesw5-dev) && \
    KEPT_PACKAGES+=(libsox-fmt-mp3) && \
    KEPT_PACKAGES+=(libusb-1.0-0) && \
    KEPT_PACKAGES+=(libusb-1.0-0-dev) && \
    KEPT_PACKAGES+=(libxft2) && \
    KEPT_PACKAGES+=(libxft-dev) && \
    KEPT_PACKAGES+=(mailutils) && \
#    KEPT_PACKAGES+=(make) && \
    KEPT_PACKAGES+=(nginx) && \
    KEPT_PACKAGES+=(php7.4-fpm) && \
    KEPT_PACKAGES+=(php7.4-mbstring) && \
    KEPT_PACKAGES+=(php7.4-sqlite3) && \
    KEPT_PACKAGES+=(python3-apt) && \
    KEPT_PACKAGES+=(python3-dev) && \
    KEPT_PACKAGES+=(python3-ephem) && \
    KEPT_PACKAGES+=(python3-idna) && \
    KEPT_PACKAGES+=(python3-jsonschema) && \
    KEPT_PACKAGES+=(python3-matplotlib) && \
    KEPT_PACKAGES+=(python3-numpy) && \
#    KEPT_PACKAGES+=(python3-opencv) && \
    KEPT_PACKAGES+=(python3-pillow) && \
    KEPT_PACKAGES+=(python3-pip) && \
    KEPT_PACKAGES+=(python3-pyrsistent) && \
    KEPT_PACKAGES+=(python3-requests) && \
    KEPT_PACKAGES+=(python3-yaml) && \
    KEPT_PACKAGES+=(python-setuptools) && \
    KEPT_PACKAGES+=(rtl-sdr) && \
    KEPT_PACKAGES+=(socat) && \
    KEPT_PACKAGES+=(sox) && \
    KEPT_PACKAGES+=(sqlite3) && \
    KEPT_PACKAGES+=(xfonts-75dpi) && \
    KEPT_PACKAGES+=(xfonts-base) && \
    #
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(cmake) && \
    TEMP_PACKAGES+=(cmake-data) && \
    TEMP_PACKAGES+=(cpp-10) && \
    TEMP_PACKAGES+=(g++) && \
    TEMP_PACKAGES+=(gcc) && \
    TEMP_PACKAGES+=(gcc-10) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(systemd) && \
    # KEPT_PIP3_PACKAGES+=(ansible-core) && \
# other packages:
    KEPT_PACKAGES+=(unzip) && \
    KEPT_PACKAGES+=(psmisc) && \
    KEPT_PACKAGES+=(iputils-ping) && \
    KEPT_PACKAGES+=(nano) && \
#
# --------------------------------------------------------------------------------------------
# Install all the apt, pip3, and gem (ruby) packages:
    apt-get update -q && \
    apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests ${TEMP_PACKAGES[@]} ${KEPT_PACKAGES[@]} && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 100 && \
#
#  Pip3 installs arent necessary because the modules in requirements.txt are already installed via APT
#    pip3 install ${KEPT_PIP3_PACKAGES[@]} && \
#
# --------------------------------------------------------------------------------------------
# Install a bunch of other things from the repo
# This is done here rather than in a COPY command to keep the image clean
    mkdir -p /git && \
    if [ -n "$BRANCH" ]; then BRANCHSTRING="-b $BRANCH"; else BRANCHSTRING=""; fi && \
    git clone --depth=1 $BRANCHSTRING https://github.com/kx1t/docker-raspberry-noaa-v2.git  /git/docker-raspberry-noaa-v2 && \
#
# Install wxtoimg
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then dpkg -i wxtoimg-armhf-2.11.2-beta.deb; \
        elif [ "$TARGETARCH" == "amd64" ]; then dpkg -i wxtoimg-amd64-2.11.2-beta.deb; \
        elif [ "$TARGETARCH" == "386"  ]; then dpkg -i wxtoimg_2.10.11-1_i386.deb; \
        elif [ "$TARGETARCH" == "arm64" ]; then \
            dpkg --add-architecture armhf && \
            apt-get update -q && apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests libc6:armhf libstdc++6:armhf libasound2:armhf libx11-6:armhf libxft-dev:armhf libxft2:armhf ghostscript && \
            dpkg -i wxtoimg-armhf-2.11.2-beta.deb && \
            apt-get clean -y -q; \
        else echo "No target for wxtoimg for $TARGETARCH" && exit 1; \
        fi && \
    popd && \
#
# Install predict
pushd /git/docker-raspberry-noaa-v2/software && \
    if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then cp predict_armhf /usr/bin/predict; \
    elif [ "$TARGETARCH" == "amd64" ]; then cp predict_amd64 /usr/bin/predict; \
    elif [ "$TARGETARCH" == "arm64" ]; then cp predict_arm64 /usr/bin/predict; \
    else echo "No target for predict for $TARGETARCH" && exit 1; \
    fi && \
popd && \
#
# Install meteor_demod
# Removed for now -- done at runtime startup
    # pushd /git/docker-raspberry-noaa-v2/software && \
    #     if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then dpkg -i Meteordemod-2.3.1-armhf.deb; \
    #     elif [ "$TARGETARCH" == "amd64" ]; then dpkg -i Meteordemod-2.3.1-amd64.deb; \
    #     elif [ "$TARGETARCH" == "arm64" ]; then dpkg -i Meteordemod-2.3.1-arm64.deb; \
    #     else echo "No target for meteor_demod for $TARGETARCH" && exit 1; \
    #     fi && \
    # popd && \
#
# Install medet
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then cp medet_armhf /usr/bin/medet; \
        elif [ "$TARGETARCH" == "amd64" ]; then cp medet_amd64 /usr/bin/medet; \
        elif [ "$TARGETARCH" == "arm64" ]; then cp medet_arm64 /usr/bin/medet; \
        else echo "No target for medet for $TARGETARCH" && exit 1; \
        fi && \
    popd && \
# Install wkhtmltoimg -- it is done here because we have more control over the arch here than in ansible
    # pushd /tmp && \
    #     if [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then cp /git/docker-raspberry-noaa-v2/rootfs/root/software/wxtoimg-armhf-2.11.2-beta.deb wkhtmltox.deb; \
    #                                      else curl -sL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_$TARGETARCH.deb -o wkhtmltox.deb; fi && \
    #     dpkg -i wkhtmltox.deb && \
    # popd && \
#
# Install wkhtmltox
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then dpkg -i wkhtmltox_0.12.6.1-2.raspberrypi.bullseye_armhf.deb; \
        elif [ "$TARGETARCH" == "amd64" ]; then dpkg -i wkhtmltox_0.12.6.1-2.bullseye_amd64.deb; \
        elif [ "$TARGETARCH" == "arm64" ]; then dpkg -i wkhtmltox_0.12.6.1-2.bullseye_arm64.deb; \
        else echo "No target for wkhtlmtox for $TARGETARCH" && exit 1; \
        fi && \
    popd && \
#
# Install noaa-apt
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ] || [ "$TARGETARCH" == "arm64" ]; then cp noaa-apt-arm /usr/bin/noaa-apt; \
        elif [ "$TARGETARCH" == "amd64" ]; then dpkg -i noaa-apt_1.3.1-1_amd64.deb; \
        else echo "No target for noaa-apt for $TARGETARCH" && exit 1; \
        fi && \
    popd && \
#
# Install udev rules
    mkdir -p /etc/udev/rules.d && \
    curl -sL -o /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules && \
#
# --------------------------------------------------------------------------------------------
#
# Clean up
    echo "Uninstalling ${TEMP_PACKAGES[*]}" && \
    # Needed because the dependency in meteordemod isn't well defined - it will get autoremoved otherwise:
    apt-mark manual python3-opencv && \
    apt-get remove --purge -y -q "${TEMP_PACKAGES[@]}" && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y -q && \
    rm -rf \
      /src/* \
      /tmp/* \
      /var/lib/apt/lists/* \
      /.dockerenv \
      /git \
      /wxtoimg \ && \
#
# --------------------------------------------------------------------------------------------
#
# Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc
#
# --------------------------------------------------------------------------------------------
#

COPY rootfs/ /

#
# No need for SHELL and ENTRYPOINT as those are inherited from the base image
#

EXPOSE 80
