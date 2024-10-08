#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

VIDEO_FILE=IMGRES_FirstRoughEdit_V1.0_DH_11.09.24.mp4
FRAME_WIDTH=512

# remove all existing frames
rm -f frame-*.png

# generate a bunch of new frames
# crop square from middle of input video
ffmpeg -i $VIDEO_FILE -vf "crop=in_h:in_h:(in_w-in_h)/2:0,scale=$FRAME_WIDTH:$FRAME_WIDTH" -vsync 0 frame-%04d.png

# original command (commented out)
# ffmpeg -i $VIDEO_FILE -vf "crop=ih:ih,scale=$FRAME_WIDTH:$FRAME_WIDTH" -vsync 0 frame-%04d.png

# extract audio from video (wav to minimize futzing with gstreamer plugins)
ffmpeg -y -i $VIDEO_FILE -vn -acodec pcm_s16le -ar 44100 -ac 2 audio.wav
