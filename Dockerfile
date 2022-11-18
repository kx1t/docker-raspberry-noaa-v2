FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python AS build
RUN set -x && \
    BUILD_PACKAGES=() && \
    # BUILD_PACKAGES+=(python3-dev) && \
    # BUILD_PACKAGES+=(python3-pip) && \
    BUILD_PACKAGES+=(cmake) && \
    BUILD_PACKAGES+=(build-essential) && \
    BUILD_PACKAGES+=(pkg-config) && \
    BUILD_PACKAGES+=(git) && \
    # BUILD_PACKAGES+=(libatlas-base-dev) && \
    # BUILD_PACKAGES+=(liblapacke-dev) && \
    # BUILD_PACKAGES+=(gfortran) && \
    # BUILD_PACKAGES+=(libopencv-dev) && \
    # BUILD_PACKAGES+=(python3-opencv) && \
    # #
    # now install these packages:
    apt-get update -q && \
    apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests "${BUILD_PACKAGES[@]}" && \

    # get and build MeteorDemod:
    mkdir /git && \
    cd /git && \
    git clone --depth=1 https://github.com/Digitelektro/MeteorDemod.git && \
    cd MeteorDemod && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake ../ && \
    make -j4 && \
    make install && \
    cpack && \
    cp *.deb /meteordemod2.deb
#
#     # Instead, build meteor_demod:
#     mkdir /git && \
#     cd /git && \
#     git clone --depth=1 https://github.com/dbdexter-dev/meteor_demod.git && \
#     cd meteor_demod && \
#     mkdir build && cd build && \
#     cmake -DENABLE_TUI=OFF .. && \
#     make

FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

COPY --from=build /git/meteor_demod/build/meteor_demod /usr/local/bin/meteor_demod
ARG TARGETARCH
ENV NOAA_HOME="/RaspiNOAA2"
ARG BRANCH="main"

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    ARM64_PACKAGES=() && \
    KEPT_PIP3_PACKAGES=() && \
    KEPT_RUBY_PACKAGES=() && \
    #
    KEPT_PACKAGES+=(ansible) && \
    KEPT_PACKAGES+=(at) && \
    KEPT_PACKAGES+=(bc) && \
    KEPT_PACKAGES+=(composer) && \
#    KEPT_PACKAGES+=(cron)
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
    KEPT_PACKAGES+=(python3-opencv) && \
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
    # KEPT_PACKAGES+=(/software/meteordemod2.deb) && \
    KEPT_PACKAGES+=(ghostscript) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(pkg-config) && \
# armhf packages for use with arm64 -- neded for wxtoimg on arm64:
    ARM64_PACKAGES+=(libc6:armhf) && \
    ARM64_PACKAGES+=(libstdc++6:armhf) && \
    ARM64_PACKAGES+=(libasound2:armhf) && \
    ARM64_PACKAGES+=(libx11-6:armhf) && \
    ARM64_PACKAGES+=(libxft-dev:armhf) && \
    ARM64_PACKAGES+=(libxft2:armhf) && \
# other packages:
    KEPT_PACKAGES+=(unzip) && \
    KEPT_PACKAGES+=(psmisc) && \
    KEPT_PACKAGES+=(iputils-ping) && \
    KEPT_PACKAGES+=(nano) && \
#
# --------------------------------------------------------------------------------------------
# Install all the apt packages:
    if [ "$TARGETARCH" == "arm64" ]; then dpkg --add-architecture armhf; else ARM64_PACKAGES=(); fi && \
    apt-get update -q && \
    apt-get install -q -o Dpkg::Options::="--force-confnew" -y --no-install-recommends --no-install-suggests "${TEMP_PACKAGES[@]}" "${KEPT_PACKAGES[@]}" "${ARM64_PACKAGES}" && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 100 && \
# --------------------------------------------------------------------------------------------
# Install a bunch of other things from the repo
# This is done here rather than in a COPY command to keep the image clean
    mkdir -p /git && \
    if [ -n "$BRANCH" ]; then BRANCHSTRING="-b $BRANCH"; else BRANCHSTRING=""; fi && \
    git clone --depth=1 $BRANCHSTRING https://github.com/kx1t/docker-raspberry-noaa-v2.git  /git/docker-raspberry-noaa-v2 && \
#
# Install wxtoimg
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "${TARGETARCH:0:3}" == "arm" ]; then dpkg -i wxtoimg-armhf-2.11.2-beta.deb; \
        elif [ "$TARGETARCH" == "amd64" ]; then dpkg -i wxtoimg-amd64-2.11.2-beta.deb; \
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
    pushd /git/docker-raspberry-noaa-v2/software && \
        if   [ "$TARGETARCH" == "armhf" ] || [ "$TARGETARCH" == "arm" ]; then cp meteor_demod_armhf /usr/local/bin/meteor_demod; \
        elif [ "$TARGETARCH" == "amd64" ]; then cp meteor_demod_amd64 /usr/local/bin/meteor_demod; \
        elif [ "$TARGETARCH" == "arm64" ]; then cp meteor_demod_arm64 /usr/local/bin/meteor_demod; \
        else echo "No target for predict for $TARGETARCH" && exit 1; \
        fi && \
    popd && \
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
    # apt-mark manual python3-opencv  # not needed as this is moved to the runtime
    apt-get remove --purge -y -q "${TEMP_PACKAGES[@]}" && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y -q && \
    rm -rf \
      /src/* \
      /tmp/* \
      /var/lib/apt/lists/* \
      /.dockerenv \
      /git \
      /wxtoimg && \
#
# --------------------------------------------------------------------------------------------
#
# Do some other stuff
    ln -sf /usr/bin/meteordemod /usr/local/bin/meteordemod
#
# --------------------------------------------------------------------------------------------
#
COPY rootfs/ /
#
# Add and install MeteorDemod2.pkg:


#
# No need for SHELL and ENTRYPOINT as those are inherited from the base image
#

EXPOSE 80
