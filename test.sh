#!/bin/bash

# be a good systemd service citizen
set -euo pipefail
IFS=$'\n\t'


docker build . --tag storytellers \
    && docker run --rm -it \
    --volume $(pwd)/assets:/app/assets \
    --volume $HF_HOME:/data/models/huggingface \
    --device /dev/video0:/dev/video0 \
    storytellers python3 pipeline_test.py
