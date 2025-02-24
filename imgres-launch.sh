#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# Configuration
readonly SCREEN1_URL="http://${IMGRES_AUTH}@imgres.fly.dev"
readonly SCREEN2_URL="http://${IMGRES_AUTH}@imgres.fly.dev?capture"
# readonly SCREEN2_URL="http://${IMGRES_AUTH}@imgres.fly.dev?capture_box=150,0,410,280"

# Check if IMGRES_AUTH environment variable is set
if [[ -z "${IMGRES_AUTH}" ]]; then
    printf "Error: IMGRES_AUTH environment variable is not set\n" >&2
    exit 1
fi

printf "Quitting Chromium if it's running...\n"
if ! pkill chromium; then
    printf "No Chromium instances found running\n"
fi

# Wait for Chromium to fully quit
sleep 2

printf "Opening Chromium with specific arguments...\n"
# Launch Display window on HDMI-A-1
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --enable-features=OverlayScrollbar \
    --class="chromium-browser-screen1" \
    --user-data-dir=/tmp/chromium_screen1 \
    --window-position=0,0 \
    --window-size=1920,1080 \
    --enable-wayland-server \
    --ozone-platform=wayland \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required \
    "${SCREEN1_URL}" >/dev/null 2>&1 &

printf "Opening second window...\n"
sleep 2

# Launch Capture window on HDMI-A-2
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --enable-features=OverlayScrollbar \
    --class="chromium-browser-screen2" \
    --user-data-dir=/tmp/chromium_screen2 \
    --window-position=1920,0 \
    --window-size=1920,1080 \
    --enable-wayland-server \
    --ozone-platform=wayland \
    --disable-gpu-driver-bug-workarounds \
    --ignore-gpu-blocklist \
    --disable-features=UseChromeOSDirectVideoDecoder \
    "${SCREEN2_URL}" >/dev/null 2>&1 &

printf "Setup complete - all windows positioned and fullscreened\n"
