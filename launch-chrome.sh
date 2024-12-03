#!/bin/bash

SLEEP_DURATION=10
CAPTURE_PARAMS="capture" # "capturebox=100,100,800,600"

# Check if IMGRES_AUTH environment variable is set
if [ -z "$IMGRES_AUTH" ]; then
    echo "Error: IMGRES_AUTH environment variable is not set" >&2
    exit 1
fi

echo "Quitting Chrome if it's running..."
osascript -e 'tell application "Google Chrome" to if it is running then quit'

# Wait for Chrome to fully quit
sleep $SLEEP_DURATION

echo "Opening Chrome with specific arguments..."
open -a "Google Chrome" --new --args \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required


sleep $SLEEP_DURATION

echo "Opening and positioning Chrome windows..."
osascript <<EOF
tell application "Google Chrome"
    # Create first window (secondary screen)
    set bounds of window 1 to [2000, 100, 2800, 600]
    set URL of active tab of window 1 to "http://$IMGRES_AUTH@imgres.fly.dev"

    # Wait a moment
    delay $SLEEP_DURATION

    # Create second window (primary screen)
    make new window
    set bounds of window 1 to [100, 100, 800, 600]
    set URL of active tab of window 1 to "http://$IMGRES_AUTH@imgres.fly.dev?$CAPTURE_PARAMS"

    # Wait for windows to settle and titles to update
    delay $SLEEP_DURATION
end tell

# Make windows fullscreen one at a time using titles
tell application "System Events"
    tell application "Google Chrome" to activate
    delay $SLEEP_DURATION

    # Find and fullscreen Capture window
    tell application "Google Chrome"
        set captureWin to (first window whose title contains "Capture")
        set index of captureWin to 1
    end tell
    delay $SLEEP_DURATION
    keystroke "f" using {command down, control down}

    delay $SLEEP_DURATION

    # Find and fullscreen Display window
    tell application "Google Chrome"
        set displayWin to (first window whose title contains "Display")
        set index of displayWin to 1
    end tell
    delay $SLEEP_DURATION
    keystroke "f" using {command down, control down}
end tell
EOF

echo "Setup complete - all windows positioned and fullscreened"
