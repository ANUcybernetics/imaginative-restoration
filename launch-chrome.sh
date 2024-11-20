# Open Chrome on first monitor
open -a "Google Chrome" --new --args \
    --new-window \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --start-fullscreen \
    "http://imgres.fly.dev?capture_box=70,90,470,300"


# Wait a moment to ensure first window is opened
sleep 2

# Open Chrome on second monitor
open -a "Google Chrome" --new --args \
    --new-window \
    --auth-server-whitelist="imgres.fly.dev" \
    --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
    --start-fullscreen \
    "http://imgres.fly.dev"
