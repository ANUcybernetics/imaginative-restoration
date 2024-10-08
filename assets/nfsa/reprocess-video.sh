#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

VIDEO_FILE=IMGRES_FirstRoughEdit_V1.0_DH_11.09.24.mp4
FRAME_WIDTH=256

# remove all existing frames
rm -f frame-*.png

# generate a bunch of new frames
ffmpeg -i $VIDEO_FILE -vf "crop=$FRAME_WIDTH:$FRAME_WIDTH*ih/iw:0:0,scale=$FRAME_WIDTH:-1" -vsync 0 frame-%04d.png

# extract audio from video (wav to minimize futzing with gstreamer plugins)
ffmpeg -y -i $VIDEO_FILE -vn -acodec pcm_s16le -ar 44100 -ac 2 audio.wav
