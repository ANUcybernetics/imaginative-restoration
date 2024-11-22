#!/bin/bash

# Check if IMGRES_AUTH environment variable is set
if [ -z "$IMGRES_AUTH" ]; then
    echo "Error: IMGRES_AUTH environment variable is not set" >&2
    exit 1
fi

# Open first Chrome window
open -a "Google Chrome" --new --args \
    --new-window \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required \
    "http://$IMGRES_AUTH@imgres.fly.dev?capture_box=70,90,470,300"

# Wait for first window to open
sleep 5

# Open second Chrome window and position it on second monitor using AppleScript
osascript <<EOF
tell application "Google Chrome"
    make new window
    set bounds of front window to [2560, 200, 3560, 800] # should be on second monitor
    tell front window
        set URL of active tab to "http://$IMGRES_AUTH@imgres.fly.dev"
    end tell
end tell
EOF

# Set the second window to fullscreen mode
sleep 5
osascript <<EOF
tell application "System Events"
    tell application "Google Chrome"
        # Set first window to fullscreen
        set index of first window to 1
        keystroke "f" using {command down, control down}

        # Set second window to fullscreen
        set index of second window to 1
        keystroke "f" using {command down, control down}
    end tell
end tell
EOF
