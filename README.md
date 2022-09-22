![Raspberry NOAA](rootfs/RaspiNOAA2/assets/header_1600_v2.png)

Looking for support, wanting to talk about new features, or just hang out? Come chat with us on [Discord!](https://discord.gg/A9w68pqBuc)

# Containerized Version of Raspberry NOAA V2

The group at [jekhokie/raspberry-noaa-v2](https://githib.com/jekhokie/raspberry-noaa-v2) implemented a fantastic NOAA and METEOR weather image capturing package. Unfortunately, it had a few issues that made it ever harder to deploy this in the modern world:

- The build was for `armhf` and (with some efforts) `arm64` only
- It was hard to install and configure, unless you'd put a full image on a further unused Raspberry Pi
- non-image installations would only work if used with username '`pi`'
- It was limited to Raspberry Pi hardware
- The builds relied on ever older versions of the Raspberry Pi OS

To remedy this, I created a fork of the repository, and made it work as a Docker Container.
Here are a few "features" and "to-dos" for this containerized version:

- All configuration is done using Docker Environment Variables that can be easily configured in a [`docker-compose.yml`](docker-compose.yml) file
- Runs in Docker with multi-architecture builds available for `armhf` (Raspberry OS - 32 bits), `arm64` (Raspberry Pi OS - 64 bits and Ubuntu on Raspberry Pi), and `amd64` (Linux PC)
- Can easily coexist with other software packages on the same machine -- of course, it still needs its own dedicated SDR
- Can now fully work behind a Reverse Web Proxy -- check out [this containerized (Docker) reverse proxy](https://github.com/sdr-enthusiasts/docker-reversewebproxy) that you can easily configure
- Included a number of fixes
- Technically, moved much of the software installation from `ansible` to the `Dockerfile` so it is installed at build-time rather than at runtime

To-dos include:
- more extensive testing on armhf and arm64
- Some of the add-on features have not been tested at all, including ~~Discord~~ (*Discord tested & works 9/22/2022*), Twitter and other notification
- The package is LARGE -- about 600-700 MB total. This is mainly caused by large package installs like `ansible`. It will be hard to reduce download size, but we'll continue optimizing where we can.

The original documentation for Raspberry NOAA V2 is available [here](rootfs/RaspiNOAA2/docs/README.md). All other available documentation can be found [in this directory](rootfs/RaspiNOAA2/docs/).

# Installation

## Installation of Docker and prerequisites
- Basic needs:
    - a Raspberry Pi 3B+, Raspberry Pi 4, or a Linux PC (laptop) with Ubuntu installed. If you use a Raspberry Pi, you can use Raspberry Pi OS (32 or 64 bits version) or Ubuntu. Personally, I've found Raspberry Pi OS (Bullseye) or Ubuntu 22.04 LTS to be excellent choices, but other relatively new OS versions will work as well
    - a SDR that can be dedicated to the project with a suitable antenna for weather satellite reception.
    - you should know some basic Linux commands -- logging in via `ssh`, creating and entering directories, using the `nano` editor, etc. It is beyond the scope of this README to teach you that.
- A prerequisite for running this package is to have `Docker` (including the `Docker Compose` plugin) installed. If you haven't done this, feel free to use the handy install script [from this repository](https://github.com/sdr-enthusiasts/docker-install).

## Configuring the RaspiNOAA2 container
- Create a directory to use as your base and go to this directory. It doesn't really matter what you name it or where you put it. We'll use `~/noaa` as an example.
NOTE -- If you have other `docker-compose` stacks running on the same system, I recommend to use a separate directory and `docker-compose.yml` file and not adding RN2 to the existing stack. The Raspberry NOAA 2 container is independent of all other packages, and we want to avoid including it in your `watchtower` auto-update routines.
```
mkdir -p ~/noaa
cd ~/noaa
```
- Download the example [`docker-compose.yml`](docker-compose.yml) file to this directory:
```
curl https://raw.githubusercontent.com/kx1t/docker-raspberry-noaa-v2/main/docker-compose.yml -o docker-compose.yml
```
- Edit this file. The easiest way is to use `nano` for this:
```
nano docker-compose.yml
```
Update the parameters the same way as you would edit the `settings.yml` file in the original project. [Here](https://github.com/kx1t/docker-raspberry-noaa-v2/blob/main/rootfs/RaspiNOAA2/config/settings.yml) are some of the parameters and their explanation -- note, when using Docker you ONLY need to update `docker-compose.yml` -- the program will take care of the rest for you.
BE CAREFUL -- using the correct indentation is VERY IMPORTANT. Don't replace spaces with (less/more) spaces or tabs, etc. You will break things.
Also -- the format of the data in `docker-compose.yml` is `      - parameter=value`.
A few new parameters that are specific to this Docker implementation:

| Parameter | Default | Description |
|-----|-----|----|
| `VERBOSELOGS` | (not present) | If this parameter has any value, the Docker Logs will contain verbose information about the execution of the container. This is great for debugging! |
| `web_baseurl` | (not present) | If you use a reverse web proxy, please set this to the base URL where your website can be reached. For example: `web_baseurl=http://kx1t.com/noaa` . If you don't use a reverse web proxy, then you can leave this empty. |

Other parameters in `docker-compose.yml` include:
- setting your web port. The default is `89`. You can change this in the `ports:` section by changing `89:80` into `xxx:80` where `xxx` is your desired HTTP port
- take note of the `volumes:` section.
    - In the first 2 lines, we pass the time and timezone of the host machine to the Docker Container. Whatever you set your timezone to on the machine, that will also be used by Docker.
    - The next 2 lines "mount" volumes that contain you images/audio/videos and your database. Mounting these will ensure that the data will be retained between restarts of the container
- take note of the `devices:` section. This is needed to expose access to the USB ports from the container.
- `container_name` contains the name you give to the container. Name it whatever you want; I'd advise to keep the `hostname` parameter set to the same value for consistency

# Running the program
From the directory where your `docker-compose.yml` is located, give this command:
```
docker compose up -d
```
RaspiNOAA2 will be downloaded (this may take a while -- about 700 MB!) and will start.
You can reach the web page about 30 seconds after you `docker compose up -d` is done.
The container logs will show a message like `php-fpm7.4 is ready` once everything is up and running.

# Logs and Troubleshooting
- You can see the Container Logs with this command. Note - if you have set `VERBOSELOGS=true`, these logs can be very verbose! If you include the `-f` flag, it will continuously show more logs as they are generated until you press CTRL-c. If you changed your container name, replace `noaa` accordingly:
```
docker logs -f noaa
```
- Downloading and starting a new version of the container
```
cd ~/noaa
docker-compose pull
docker-compose up -d
```
- Stopping (and optionally removing) the container. Note - if you remove the container, it will need to be downloaded again next time you try to run it. Your database and audio/image/video files will stay intact.
```
docker stop noaa
docker rm noaa
```
- Making configuration changes after startup
```
cd ~/noaa
nano docker-compose.yml   # make your changes and save the file
docker-compose up -d      # restart the RN2 container with the new parameters
```

If you run into trouble, please join us at the Discord server (link at the top). It would be very useful if you had some logs -- for example do this:
```
docker restart noaa && sleep 30 && docker logs -n 500 noaa | nc termbin.com 9999
```
Then send us the link that is returns after about 30 seconds. If it complaints that it cannot find `nc`, then do `sudo apt update && sudo apt install -y netcat` and try that line again.

# Build download / container creation / configuration timing
As written above, the container is LARGE. Here are some timing measurements for a system to become available. In this case, we started FROM SCRATCH. This means, that all layers needed to be downloaded. Normally, when you do a "quick update", no (or minimal) downloads need to happen.
The measurements were taken on 22 September 2022, using a wired 100 Mbps connection to a 1 GB fiber internet connection. The measurements were conducted in series to avoid filling up the network bandwidth.

| Device/Architecture | Time to download and expand | Time to create and start container | Time for container to be fully up and running | TOTAL TIME |
|---------------------|-----------------------------|------------------------------------|--------------------------------------------------|------------------|
| RPi 3B+ / armhf     | 1238 secs | 9.6 secs | 145 secs | 1392.6 secs |
| RPi 4B (4Gb) / arm64 | 627 secs | 16 secs | 90 secs | 733 secs |
| Dell XPS 13* / amd64 | 129 secs | 2.5 secs | 40 secs | 171.5 secs |

Any subsequent restarts should not cause any "download and expand" time, unless you specifically request the container to be pulled.

* The Dell XPS 13 was an older model Intel(R) Core(TM) i5-3317U CPU @ 1.70GHz dual (2) core

# License
The software packages and OS layers included in this project are used with permission under license terms that are distributed with these packages. Specifically, the GPL 3.0 license terms for the original, non-containerized version of "Raspberry NOAA 2" can be found [here](https://github.com/jekhokie/raspberry-noaa-v2/blob/master/LICENSE).

The combination of these packages and any additional software written to containerize, expand, and configure "Raspberry NOAA 2" are Copyright (C) 2022 by kx1t, and licensed under the GNU General Public License, version 3 or later.

Summary of License Terms This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.
