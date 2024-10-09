#!/bin/bash

PLAY_AUDIO=0

# be a good systemd service citizen
set -euo pipefail
IFS=$'\n\t'

xhost +local:docker

# Start ffplay in the background, looping the audio file if PLAY_AUDIO is set to 1
if [ "${PLAY_AUDIO:-0}" = "1" ]; then
    ffplay -nodisp -loop 0 assets/nfsa/audio.wav &
    FFPLAY_PID=$!
fi

# Run the Docker container
docker run --rm -it \
    --device=/dev/video0:/dev/video0 \
    --env DISPLAY=$DISPLAY \
    --volume /tmp/.X11-unix:/tmp/.X11-unix \
    --volume $HF_HOME:/data/models/huggingface \
    storytellers

# When Docker container exits, kill ffplay if it was started
if [ "${PLAY_AUDIO:-0}" = "1" ]; then
    kill $FFPLAY_PID
fi
