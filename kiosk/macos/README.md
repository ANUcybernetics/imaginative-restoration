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

4. **Configure authentication**
   Edit `~/.kiosk/.env` and add your authentication:
   ```bash
   IMGRES_AUTH=your-auth-string-here
   ```

5. **Restart the Mac mini**
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
- Logs all activity to `~/Library/Logs/imgres-kiosk.log`

## Display Configuration

- **Display 1 (Secondary)**: Shows capture view with bounding box
- **Display 2 (Primary)**: Shows full display view

## Troubleshooting

### Check logs
```bash
tail -f ~/Library/Logs/imgres-kiosk.log
tail -f ~/Library/Logs/imgres-kiosk.error.log
```

### Manually start/stop the kiosk
```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.imgres.kiosk.plist

# Start
launchctl load ~/Library/LaunchAgents/com.imgres.kiosk.plist
```

### Test the launch script manually
```bash
export IMGRES_AUTH=your-auth-string
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

## Security Considerations

- The `IMGRES_AUTH` credential is stored in plaintext in `~/.kiosk/.env`
- Auto-login is enabled, so physical access equals full access
- Consider using FileVault if the Mac mini is in an unsecured location
- The setup disables various security features (sleep, screen lock)

## Customization

To modify URLs or display positioning, edit the configuration section at the top of `imgres-launch-macos.sh`.

The script includes:
- Automatic restart on Chrome crash
- Retry logic (3 attempts)
- Comprehensive error handling and logging
- Window count monitoring
- Graceful Chrome shutdown with force-quit fallback