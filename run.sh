#!/bin/bash

# be a good systemd service citizen
set -euo pipefail
IFS=$'\n\t'

xhost +local:docker
docker run --rm -it --device=/dev/video0:/dev/video0 --env DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix storytellers
