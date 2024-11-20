#!/bin/bash

# Open first Chrome window
open -a "Google Chrome" --new --args \
    --new-window \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --autoplay-policy=no-user-gesture-required \
    --start-fullscreen \
    "http://imgres.fly.dev?capture_box=70,90,470,300"

# Wait for first window to open
sleep 3

# Open second Chrome window and position it on second monitor using AppleScript
osascript <<EOF
tell application "Google Chrome"
    make new window
    set bounds of front window to [2560, 0, 5120, 1440] # Adjust these coordinates based on your monitor setup
    tell front window
        set URL of active tab to "http://imgres.fly.dev"
    end tell
end tell
EOF

# Set the second window to fullscreen mode
sleep 2
osascript <<EOF
tell application "System Events"
    keystroke "f" using {command down, control down}
end tell
EOF
