#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
set -x           # Enable debugging output

# Configuration
# readonly SCREEN1_URL="http://${IMGRES_AUTH}@imgres.fly.dev"
readonly SCREEN1_URL="http://${IMGRES_AUTH}@imgres.fly.dev?capture_box=150,0,410,280"
readonly SCREEN2_URL="http://${IMGRES_AUTH}@imgres.fly.dev"

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

    # Wait for windows to settle
    delay 10
end tell

# Make windows fullscreen using URL matching instead of titles
tell application "System Events"
    tell application "Google Chrome" to activate
    delay 5

    # Find and fullscreen Display window (without capture parameter)
    tell application "Google Chrome"
        set displayWin to missing value
        repeat with w in windows
            try
                set currentURL to URL of active tab of w
                if currentURL contains "imgres.fly.dev" and currentURL does not contain "capture" then
                    set displayWin to w
                    exit repeat
                end if
            end try
        end repeat

        if displayWin is not missing value then
            set index of displayWin to 1
            delay 2
        end if
    end tell

    # Fullscreen the display window
    keystroke "f" using {command down, control down}
    delay 5

    # Find and fullscreen Capture window (with capture parameter)
    tell application "Google Chrome"
        set captureWin to missing value
        repeat with w in windows
            try
                set currentURL to URL of active tab of w
                if currentURL contains "imgres.fly.dev" and currentURL contains "capture" then
                    set captureWin to w
                    exit repeat
                end if
            end try
        end repeat

        if captureWin is not missing value then
            set index of captureWin to 1
            delay 2
        end if
    end tell

    # Fullscreen the capture window
    keystroke "f" using {command down, control down}
end tell
EOF

printf "Setup complete - all windows positioned and fullscreened\n"
