#!/bin/bash

CAPTURE_PARAMS="capture" # "capture_box=150,0,410,280"

# Check if IMGRES_AUTH environment variable is set
if [ -z "$IMGRES_AUTH" ]; then
    echo "Error: IMGRES_AUTH environment variable is not set" >&2
    exit 1
fi

echo "Quitting Chrome if it's running..."
osascript -e 'tell application "Google Chrome" to if it is running then quit'

# Wait for Chrome to fully quit
sleep 2

echo "Opening Chrome with specific arguments..."
open -a "Google Chrome" --new --args \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required


sleep 5

echo "Opening and positioning Chrome windows..."
osascript <<EOF
tell application "Google Chrome"
    # Create first window (secondary screen)
    set bounds of window 1 to [2000, 100, 2800, 600]
    set URL of active tab of window 1 to "http://$IMGRES_AUTH@imgres.fly.dev"

    # Wait a moment
    delay 5

    # Create second window (primary screen)
    make new window
    set bounds of window 1 to [100, 100, 800, 600]
    set URL of active tab of window 1 to "http://$IMGRES_AUTH@imgres.fly.dev?$CAPTURE_PARAMS"

    # Wait for windows to settle and titles to update
    delay 5
end tell

# Make windows fullscreen one at a time using titles
tell application "System Events"
    tell application "Google Chrome" to activate
    delay 5

    # Find and fullscreen Capture window
    tell application "Google Chrome"
        set captureWin to (first window whose title contains "Capture")
        set index of captureWin to 1
    end tell
    delay 10
    keystroke "f" using {command down, control down}

    delay 10

    # Find and fullscreen Display window
    tell application "Google Chrome"
        set displayWin to (first window whose title contains "Display")
        set index of displayWin to 1
    end tell
    delay 10
    keystroke "f" using {command down, control down}
end tell
EOF

echo "Setup complete - all windows positioned and fullscreened"
