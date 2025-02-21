#!/bin/bash

CAPTURE_PARAMS="capture" # "capture_box=150,0,410,280"

# Check if IMGRES_AUTH environment variable is set
if [ -z "${IMGRES_AUTH}" ]; then
    echo "Error: IMGRES_AUTH environment variable is not set" >&2
    exit 1
fi

# Force X11 if needed
export GDK_BACKEND=x11
export DISPLAY=:0

echo "Quitting Chromium if it's running..."
pkill chromium

# Wait for Chromium to fully quit
sleep 2

echo "Opening Chromium with specific arguments..."
# Launch Display window on top display
chromium-browser --noerrdialogs \
    --disable-infobars \
    --start-fullscreen \
    # --window-position=1280,0 \
    --window-position=1920,0 \
    --user-data-dir=$(mktemp -d) \
    --enable-features=OverlayScrollbar \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required \
    --disable-gpu-driver-bug-workarounds \
    --ignore-gpu-blocklist \
    --disable-features=UseChromeOSDirectVideoDecoder \
    "http://${IMGRES_AUTH}@imgres.fly.dev" 2>/dev/null &

sleep 2

# Launch Capture window on "inside" display
chromium-browser --noerrdialogs \
    --disable-infobars \
    --start-fullscreen \
    --window-position=0,0 \
    --user-data-dir=$(mktemp -d) \
    --enable-features=OverlayScrollbar \
    --disable-gpu-driver-bug-workarounds \
    --ignore-gpu-blocklist \
    --disable-features=UseChromeOSDirectVideoDecoder \
    "http://${IMGRES_AUTH}@imgres.fly.dev?${CAPTURE_PARAMS}" 2>/dev/null &

echo "Setup complete - all windows positioned and fullscreened"
