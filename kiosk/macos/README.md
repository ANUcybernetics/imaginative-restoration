# macOS Kiosk Setup

This directory contains scripts to configure a Mac mini as a dual-screen Chrome kiosk for the Imaginative Restoration project.

## Files

- `setup-kiosk-mac.sh` - Main setup script to configure the Mac as a kiosk
- `imgres-launch-macos.sh` - Launch script with error recovery and automatic restart

## Requirements

- Mac mini running macOS
- Two displays connected
- Google Chrome installed
- `IMGRES_AUTH` environment variable with authentication credentials

## Setup Instructions

1. **Copy files to target Mac mini**
   ```bash
   scp -r kiosk/macos/ user@mac-mini:~/
   ```

2. **SSH into the Mac mini**
   ```bash
   ssh user@mac-mini
   ```

3. **Run the setup script**
   ```bash
   cd ~/macos
   ./setup-kiosk-mac.sh
   ```

4. **Configure authentication and capture box**
   Edit `~/.kiosk/.env` and add your configuration:
   ```bash
   # Required: Authentication credentials
   IMGRES_AUTH="your-username:your-password"
   
   # Optional: Capture box configuration (x,y,width,height)
   # Default: 150,0,410,280
   IMGRES_CAPTURE_BOX="150,0,410,280"
   ```

5. **Enable automatic login (IMPORTANT)**
   
   The script will attempt to enable auto-login via command line, but this often requires manual configuration:
   
   a. Go to **System Settings > Users & Groups**
   b. Click **Login Options** (you may need to unlock with your password)
   c. Set **Automatic login** to your username
   d. Enter your password when prompted
   e. Save the settings

6. **Restart the Mac mini**
   ```bash
   sudo reboot
   ```

## What the Setup Does

- Enables automatic login for the current user
- Disables screen saver and sleep mode
- Hides desktop icons and auto-hides the dock
- Installs a LaunchAgent to start the kiosk on login
- Configures Chrome to launch in fullscreen on both displays
- Monitors Chrome and automatically restarts if it crashes
- Logs all activity to `~/.kiosk/logs/` directory

## Display Configuration

- **Display 1 (Secondary)**: Shows capture view with bounding box
- **Display 2 (Primary)**: Shows full display view

## Troubleshooting

### Check logs
```bash
tail -f ~/.kiosk/logs/launch.log
tail -f ~/.kiosk/logs/stdout.log
tail -f ~/.kiosk/logs/stderr.log
```

### Manually start/stop the kiosk
```bash
# Stop
launchctl stop com.imgres.kiosk
launchctl unload ~/Library/LaunchAgents/com.imgres.kiosk.plist

# Start
launchctl load -w ~/Library/LaunchAgents/com.imgres.kiosk.plist
launchctl start com.imgres.kiosk
```

### Test the launch script manually
```bash
# Option 1: Source the .env file
source ~/.kiosk/.env
~/.kiosk/launch.sh

# Option 2: Set variables manually
export IMGRES_AUTH="your-username:your-password"
export IMGRES_CAPTURE_BOX="150,0,410,280"
~/.kiosk/launch.sh
```

## Uninstalling

To remove the kiosk setup and restore normal operation:

```bash
~/.kiosk/uninstall.sh
```

This will:
- Remove the LaunchAgent
- Disable auto-login
- Restore sleep settings
- Show desktop icons
- Restore the dock
- Remove all kiosk scripts

## Known Issues & Solutions

### Auto-login not working after setup
- FileVault must be disabled for auto-login to work
- The command-line method may not be sufficient; manual configuration through System Settings is often required
- Check FileVault status: `sudo fdesetup status`

### "Operation not permitted" errors
- macOS security may block scripts copied from external sources
- The setup script copies the launch script to `~/.kiosk/` to avoid this issue
- If you still see errors, check extended attributes: `xattr -l <file>`

### Chrome not launching
- Ensure `IMGRES_AUTH` is properly set in `~/.kiosk/.env`
- Check that variables are being exported in the launch wrapper
- Verify Chrome is installed at `/Applications/Google Chrome.app`

## Security Considerations

- The `IMGRES_AUTH` credential is stored in plaintext in `~/.kiosk/.env`
- Auto-login is enabled, so physical access equals full access
- Consider using FileVault if the Mac mini is in an unsecured location (but note this prevents auto-login)
- The setup disables various security features (sleep, screen lock)

## Customization

### Environment Variables

All configuration is managed through `~/.kiosk/.env`:

- `IMGRES_AUTH` (required) - Authentication credentials in format "username:password"
- `IMGRES_CAPTURE_BOX` (optional) - Capture box dimensions as "x,y,width,height"
  - Default: "150,0,410,280"
  - Format: "x_offset,y_offset,width,height"

To modify display positioning or other behavior, edit `imgres-launch-macos.sh`.

### Features

The script includes:
- Automatic restart on Chrome crash via LaunchAgent
- Environment-based configuration
- Comprehensive error handling and logging
- Window positioning and fullscreen automation
- Graceful Chrome shutdown with force-quit fallback