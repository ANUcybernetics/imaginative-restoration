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

# Step 1: Configure auto-login
print_status "Configuring automatic login..."
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "$KIOSK_USER"

# Step 2: Disable screen saver and sleep
print_status "Disabling screen saver and sleep..."
defaults write com.apple.screensaver askForPassword -int 0
defaults write com.apple.screensaver idleTime -int 0
sudo pmset -a displaysleep 0 disksleep 0 sleep 0
sudo pmset -a womp 1  # Wake on network access

# Step 3: Hide desktop icons and dock
print_status "Configuring desktop for kiosk mode..."
defaults write com.apple.finder CreateDesktop -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
defaults write com.apple.dock launchanim -bool false

# Step 4: Disable various macOS features
print_status "Disabling unnecessary macOS features..."
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool false
defaults write com.apple.finder ShowStatusBar -bool false
defaults write com.apple.finder ShowPathbar -bool false

# Step 5: Create launch directory if it doesn't exist
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Step 6: Copy launch script to a stable location
KIOSK_SCRIPTS_DIR="$HOME/.kiosk"
mkdir -p "$KIOSK_SCRIPTS_DIR"
cp "$SCRIPT_DIR/imgres-launch-macos.sh" "$KIOSK_SCRIPTS_DIR/launch.sh"
chmod +x "$KIOSK_SCRIPTS_DIR/launch.sh"

# Step 7: Create LaunchAgent plist
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
        <key>Crashed</key>
        <true/>
    </dict>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/imgres-kiosk.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/imgres-kiosk.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>IMGRES_AUTH</key>
        <string>\${IMGRES_AUTH}</string>
    </dict>
</dict>
</plist>
EOF

# Step 8: Check IMGRES_AUTH environment variable
print_warning "IMPORTANT: You need to set IMGRES_AUTH environment variable"
print_warning "Add this to $HOME/.zshrc or $HOME/.bash_profile:"
print_warning "export IMGRES_AUTH='your-auth-string-here'"

# Create a .env file for the LaunchAgent to source
cat > "$KIOSK_SCRIPTS_DIR/.env" <<EOF
# Add your IMGRES_AUTH value here
# IMGRES_AUTH=your-auth-string-here
EOF

# Step 9: Create wrapper script that sources environment
cat > "$KIOSK_SCRIPTS_DIR/launch-wrapper.sh" <<'EOF'
#!/bin/bash
# Source environment variables
if [[ -f "$HOME/.kiosk/.env" ]]; then
    source "$HOME/.kiosk/.env"
fi

# Also try to source from shell profile
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    source "$HOME/.bash_profile"
fi

# Execute the actual launch script
exec "$HOME/.kiosk/launch.sh"
EOF
chmod +x "$KIOSK_SCRIPTS_DIR/launch-wrapper.sh"

# Update plist to use wrapper
sed -i '' "s|<string>$KIOSK_SCRIPTS_DIR/launch.sh</string>|<string>$KIOSK_SCRIPTS_DIR/launch-wrapper.sh</string>|" "$PLIST_PATH"

# Step 10: Load the LaunchAgent
print_status "Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

# Step 11: Disable automatic updates
print_status "Disabling automatic updates..."
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false

# Step 12: Create uninstall script
print_status "Creating uninstall script..."
cat > "$KIOSK_SCRIPTS_DIR/uninstall.sh" <<EOF
#!/bin/bash
echo "Uninstalling kiosk mode..."

# Unload and remove LaunchAgent
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
print_status "2. Restart the Mac mini"
print_status ""
print_status "To uninstall: $KIOSK_SCRIPTS_DIR/uninstall.sh"
print_status ""
print_warning "The kiosk will start automatically on next login"