#!/bin/bash
set -e
set -u
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running as sudo
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. It will prompt for sudo when needed."
   exit 1
fi

print_status "Mac Mini Kiosk Setup Script"
print_status "==========================="

# Get current username
KIOSK_USER=$(whoami)
print_status "Setting up kiosk for user: $KIOSK_USER"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if launch script exists
if [[ ! -f "$SCRIPT_DIR/imgres-launch-macos.sh" ]]; then
    print_error "Launch script not found at: $SCRIPT_DIR/imgres-launch-macos.sh"
    exit 1
fi

# Step 1: Create kiosk directory structure
KIOSK_SCRIPTS_DIR="$HOME/.kiosk"
print_status "Creating kiosk directory structure..."
mkdir -p "$KIOSK_SCRIPTS_DIR/logs"
chmod 755 "$KIOSK_SCRIPTS_DIR"

# Step 2: Copy launch script to avoid "Operation not permitted" errors
print_status "Copying launch script to kiosk directory..."
cp "$SCRIPT_DIR/imgres-launch-macos.sh" "$KIOSK_SCRIPTS_DIR/imgres-launch-macos.sh"
chmod +x "$KIOSK_SCRIPTS_DIR/imgres-launch-macos.sh"

# Step 3: Create .env file template
print_status "Creating environment configuration file..."
cat > "$KIOSK_SCRIPTS_DIR/.env" <<EOF
# ImgRes authentication credentials
# Replace with your actual credentials
IMGRES_AUTH="your-username:your-password"

# Optional: Capture box configuration (x,y,width,height)
# Default: 150,0,410,280
IMGRES_CAPTURE_BOX="150,0,410,280"
EOF

print_warning "IMPORTANT: Edit $KIOSK_SCRIPTS_DIR/.env with your actual credentials"

# Step 4: Create launch wrapper that properly exports variables
print_status "Creating launch wrapper script..."
cat > "$KIOSK_SCRIPTS_DIR/launch.sh" <<'EOF'
#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Log output
exec 1>> ~/.kiosk/logs/launch.log 2>&1
echo "[$(date)] Starting kiosk launch script"

# Source environment if available
if [ -f ~/.kiosk/.env ]; then
    source ~/.kiosk/.env
fi

# Check if IMGRES_AUTH environment variable is set
if [[ -z "${IMGRES_AUTH:-}" ]]; then
    echo "Error: IMGRES_AUTH environment variable is not set" >&2
    exit 1
fi

# Export all required variables
export IMGRES_AUTH
export IMGRES_CAPTURE_BOX="${IMGRES_CAPTURE_BOX:-}"

# Kill any existing Chrome instances
pkill -f "Google Chrome" || true
sleep 2

# Launch the script
~/.kiosk/imgres-launch-macos.sh

echo "[$(date)] Kiosk launch complete"
EOF
chmod +x "$KIOSK_SCRIPTS_DIR/launch.sh"

# Step 5: Configure auto-login
print_status "Configuring automatic login..."
print_warning "Note: You may need to manually enable auto-login in System Settings > Users & Groups"
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "$KIOSK_USER"

# Step 6: Check FileVault status
FILEVAULT_STATUS=$(sudo fdesetup status 2>/dev/null || echo "Unknown")
if [[ "$FILEVAULT_STATUS" == *"FileVault is On"* ]]; then
    print_warning "FileVault is enabled - automatic login will NOT work!"
    print_warning "To disable FileVault: sudo fdesetup disable"
fi

# Step 7: Disable screen saver and sleep
print_status "Disabling screen saver and sleep..."
defaults write com.apple.screensaver askForPassword -int 0
defaults write com.apple.screensaver idleTime -int 0
sudo pmset -a displaysleep 0 disksleep 0 sleep 0
sudo pmset -a womp 1  # Wake on network access

# Step 8: Hide desktop icons and dock
print_status "Configuring desktop for kiosk mode..."
defaults write com.apple.finder CreateDesktop -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
defaults write com.apple.dock launchanim -bool false

# Step 9: Disable various macOS features
print_status "Disabling unnecessary macOS features..."
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool false
defaults write com.apple.finder ShowStatusBar -bool false
defaults write com.apple.finder ShowPathbar -bool false

# Step 10: Create LaunchAgent plist
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"
PLIST_NAME="com.imgres.kiosk"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist"

print_status "Creating LaunchAgent..."
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KIOSK_SCRIPTS_DIR/launch.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$KIOSK_SCRIPTS_DIR/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$KIOSK_SCRIPTS_DIR/logs/stderr.log</string>
    <key>WorkingDirectory</key>
    <string>$HOME</string>
</dict>
</plist>
EOF

# Step 11: Load the LaunchAgent
print_status "Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load -w "$PLIST_PATH"

# Step 12: Disable automatic updates
print_status "Disabling automatic updates..."
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false

# Step 13: Create uninstall script
print_status "Creating uninstall script..."
cat > "$KIOSK_SCRIPTS_DIR/uninstall.sh" <<EOF
#!/bin/bash
echo "Uninstalling kiosk mode..."

# Unload and remove LaunchAgent
launchctl stop com.imgres.kiosk 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"

# Remove auto-login
sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true

# Restore sleep settings
sudo pmset -a displaysleep 10 disksleep 10 sleep 30

# Restore desktop
defaults delete com.apple.finder CreateDesktop 2>/dev/null || true
defaults delete com.apple.dock autohide 2>/dev/null || true
defaults delete com.apple.dock autohide-delay 2>/dev/null || true

# Restart Finder and Dock
killall Finder
killall Dock

# Remove kiosk directory
rm -rf "$KIOSK_SCRIPTS_DIR"

echo "Kiosk mode uninstalled. Please restart the computer."
EOF
chmod +x "$KIOSK_SCRIPTS_DIR/uninstall.sh"

print_status "Setup complete!"
print_status ""
print_status "Next steps:"
print_status "1. Edit $KIOSK_SCRIPTS_DIR/.env and add your IMGRES_AUTH value"
print_status "2. If auto-login didn't work, manually enable it:"
print_status "   - Go to System Settings > Users & Groups > Login Options"
print_status "   - Set 'Automatic login' to '$KIOSK_USER'"
print_status "   - Enter your password when prompted"
print_status "3. Test the kiosk: launchctl start com.imgres.kiosk"
print_status "4. Check logs: tail -f $KIOSK_SCRIPTS_DIR/logs/launch.log"
print_status "5. Restart the Mac mini when ready"
print_status ""
print_status "To uninstall: $KIOSK_SCRIPTS_DIR/uninstall.sh"
print_status ""
print_warning "The kiosk will start automatically on next login"