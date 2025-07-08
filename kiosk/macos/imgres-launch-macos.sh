#!/bin/bash
set -e
set -u
set -o pipefail

# Configuration
readonly SCREEN1_URL="http://${IMGRES_AUTH}@imgres.fly.dev/?capture_box=150,0,410,280"
readonly SCREEN2_URL="http://${IMGRES_AUTH}@imgres.fly.dev"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=10
readonly LOG_FILE="$HOME/Library/Logs/imgres-kiosk.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if Chrome is responsive
check_chrome_responsive() {
    osascript -e 'tell application "Google Chrome" to return (count of windows)' &>/dev/null
}

# Kill Chrome forcefully if needed
force_quit_chrome() {
    log "Force quitting Chrome..."
    pkill -9 "Google Chrome" 2>/dev/null || true
    sleep 2
}

# Main launch function
launch_kiosk() {
    log "Starting kiosk launch sequence..."
    
    # Check if IMGRES_AUTH environment variable is set
    if [[ -z "${IMGRES_AUTH:-}" ]]; then
        log "Error: IMGRES_AUTH environment variable is not set"
        return 1
    fi
    
    # Quit Chrome gracefully first
    log "Attempting to quit Chrome gracefully..."
    osascript -e 'tell application "Google Chrome" to if it is running then quit' 2>/dev/null || true
    
    # Wait for Chrome to quit
    local wait_count=0
    while pgrep -q "Google Chrome" && [ $wait_count -lt 10 ]; do
        sleep 1
        ((wait_count++))
    done
    
    # Force quit if still running
    if pgrep -q "Google Chrome"; then
        force_quit_chrome
    fi
    
    log "Opening Chrome with kiosk arguments..."
    open -a "Google Chrome" --new --args \
        --auth-server-whitelist="imgres.fly.dev" \
        --auth-negotiate-delegate-whitelist="imgres.fly.dev" \
        --autoplay-policy=no-user-gesture-required \
        --disable-session-crashed-bubble \
        --disable-infobars \
        --disable-restore-session-state \
        --no-first-run \
        --disable-features=TranslateUI \
        --overscroll-history-navigation=0
    
    # Wait for Chrome to be responsive
    local chrome_wait=0
    while ! check_chrome_responsive && [ $chrome_wait -lt 30 ]; do
        sleep 1
        ((chrome_wait++))
    done
    
    if [ $chrome_wait -ge 30 ]; then
        log "Chrome failed to become responsive"
        return 1
    fi
    
    sleep 5
    
    log "Setting up Chrome windows..."
    
    # Use more robust AppleScript with error handling
    osascript <<EOF 2>&1 | tee -a "$LOG_FILE"
on error_handler(error_message)
    log "AppleScript error: " & error_message
end error_handler

try
    tell application "Google Chrome"
        activate
        
        -- Configure first window
        if (count of windows) = 0 then
            make new window
        end if
        
        set bounds of window 1 to {2000, 100, 2800, 600}
        set URL of active tab of window 1 to "${SCREEN1_URL}"
        
        delay 5
        
        -- Create second window
        make new window
        set bounds of window 1 to {100, 100, 800, 600}
        set URL of active tab of window 1 to "${SCREEN2_URL}"
        
        delay 10
    end tell
    
    -- Fullscreen windows
    tell application "System Events"
        tell application "Google Chrome" to activate
        delay 5
        
        -- Find and fullscreen windows by title
        try
            tell application "Google Chrome"
                set captureWin to (first window whose title contains "Capture")
                set index of captureWin to 1
            end tell
            delay 5
            keystroke "f" using {command down, control down}
        on error
            log "Could not find Capture window"
        end try
        
        delay 10
        
        try
            tell application "Google Chrome"
                set displayWin to (first window whose title contains "Display")
                set index of displayWin to 1
            end tell
            delay 5
            keystroke "f" using {command down, control down}
        on error
            log "Could not find Display window"
        end try
    end tell
    
    return "Success"
on error error_message
    error_handler(error_message)
    return "Failed: " & error_message
end try
EOF
    
    local result=$?
    if [ $result -eq 0 ]; then
        log "Kiosk setup completed successfully"
        return 0
    else
        log "Kiosk setup failed with exit code: $result"
        return 1
    fi
}

# Main execution with retry logic
main() {
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if launch_kiosk; then
            log "Kiosk launched successfully"
            
            # Monitor Chrome and restart if it crashes
            while true; do
                sleep 30
                if ! pgrep -q "Google Chrome"; then
                    log "Chrome has crashed, restarting..."
                    break
                fi
                
                # Check if both windows are still present
                local window_count
                window_count=$(osascript -e 'tell application "Google Chrome" to return (count of windows)' 2>/dev/null || echo "0")
                
                if [ "$window_count" -lt 2 ]; then
                    log "Chrome windows lost, restarting..."
                    break
                fi
            done
        else
            log "Launch attempt $((retry_count + 1)) failed"
        fi
        
        ((retry_count++))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            log "Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi
    done
    
    log "Failed to launch kiosk after $MAX_RETRIES attempts"
    exit 1
}

# Run main function
main