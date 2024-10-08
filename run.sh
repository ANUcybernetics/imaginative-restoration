#!/bin/bash

# be a good systemd service citizen
set -euo pipefail
IFS=$'\n\t'

xhost +local:docker

# Start ffplay in the background, looping the audio file
ffplay -nodisp -loop 0 assets/nfsa/audio.wav &
FFPLAY_PID=$!

# Run the Docker container
docker run --rm -it \
    --device=/dev/video0:/dev/video0 \
    --env DISPLAY=$DISPLAY \
    --volume /tmp/.X11-unix:/tmp/.X11-unix \
    --volume /run/user/1000/pipewire-0:/tmp/pipewire-0 \
    --volume ${XDG_RUNTIME_DIR:-/run/user/1000}:/tmp/runtime-root \
    storytellers

# When Docker container exits, kill ffplay
kill $FFPLAY_PID
