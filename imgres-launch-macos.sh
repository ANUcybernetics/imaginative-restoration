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

printf "Quitting Chrome if it's running...\n"
osascript -e 'tell application "Google Chrome" to if it is running then quit'

# Wait for Chrome to fully quit
sleep 2

printf "Opening Chrome with specific arguments...\n"
open -a "Google Chrome" --new --args \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required

sleep 5

printf "Opening and positioning Chrome windows...\n"
osascript <<EOF
tell application "Google Chrome"
    # Create first window (Display - secondary screen)
    set bounds of window 1 to [2000, 100, 2800, 600]
    set URL of active tab of window 1 to "${SCREEN1_URL}"

    # Wait a moment
    delay 5

    # Create second window (Capture - primary screen)
    make new window
    set bounds of window 1 to [100, 100, 800, 600]
    set URL of active tab of window 1 to "${SCREEN2_URL}"

    # Wait for windows to settle and titles to update
    delay 5
end tell

# Make windows fullscreen one at a time using titles
tell application "System Events"
    tell application "Google Chrome" to activate
    delay 5

    # Find and fullscreen Display window
    tell application "Google Chrome"
        set displayWin to (first window whose title contains "Display")
        set index of displayWin to 1
    end tell
    delay 10
    keystroke "f" using {command down, control down}

    delay 10

    # Find and fullscreen Capture window
    tell application "Google Chrome"
        set captureWin to (first window whose title contains "Capture")
        set index of captureWin to 1
    end tell
    delay 10
    keystroke "f" using {command down, control down}
end tell
EOF

printf "Opening second window...\n"
printf "Setup complete - all windows positioned and fullscreened\n"
