# Raspberry Pi Kiosk Setup

This directory contains scripts and configuration files to set up a Raspberry Pi as a dual-screen Chrome kiosk for the Imaginative Restoration project.

## Files

- `imgres-launch-raspbian.sh` - Launch script that starts two Chromium instances in kiosk mode
- `rc.xml` - labwc window manager configuration for proper window positioning

## Requirements

- Raspberry Pi running Raspbian with Wayland
- Two HDMI displays connected
- labwc window manager installed
- Chromium browser installed
- `IMGRES_AUTH` environment variable with authentication credentials

## Display Configuration

The setup assumes two 1920x1080 displays connected via HDMI:
- **HDMI-A-1 (Primary)**: Shows the main application interface
- **HDMI-A-2 (Secondary)**: Shows the capture interface

## Setup Instructions

1. **Install dependencies**
   ```bash
   sudo apt update
   sudo apt install chromium-browser labwc
   ```

2. **Copy configuration files**
   ```bash
   # Copy the launch script
   sudo cp imgres-launch-raspbian.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/imgres-launch-raspbian.sh
   
   # Copy labwc configuration
   mkdir -p ~/.config/labwc
   cp rc.xml ~/.config/labwc/
   ```

3. **Set up environment variable**
   Add to `~/.bashrc` or `/etc/environment`:
   ```bash
   export IMGRES_AUTH=your-auth-string-here
   ```

4. **Configure auto-start**
   Create a systemd service or add to your session autostart:
   ```bash
   # For labwc autostart
   mkdir -p ~/.config/labwc
   echo "/usr/local/bin/imgres-launch-raspbian.sh" >> ~/.config/labwc/autostart
   ```

5. **Enable auto-login** (if needed)
   ```bash
   sudo raspi-config
   # Navigate to: System Options > Boot / Auto Login > Desktop Autologin
   ```

## How It Works

1. The `rc.xml` configuration tells labwc to:
   - Position `chromium-browser-screen1` at (0,0) and maximize it
   - Position `chromium-browser-screen2` at (1920,0) and maximize it
   - Remove all window gaps for seamless display

2. The launch script:
   - Validates the `IMGRES_AUTH` environment variable
   - Launches two separate Chromium instances with:
     - Full kiosk mode (no UI elements)
     - Separate user data directories to maintain independent sessions
     - Authentication whitelist for imgres.fly.dev
     - Autoplay enabled for media content
   - Each instance opens a different URL on the target displays

## Troubleshooting

### Check if displays are detected
```bash
wlr-randr
```

### Test the launch script manually
```bash
export IMGRES_AUTH=your-auth-string
/usr/local/bin/imgres-launch-raspbian.sh
```

### View Chromium logs
```bash
journalctl -f -u session-*.scope
```

### Common Issues

- **Black screen**: Ensure both HDMI cables are connected before boot
- **Wrong display assignment**: Swap HDMI cables or modify the script's display names
- **Authentication fails**: Verify `IMGRES_AUTH` is set correctly
- **Windows not positioned correctly**: Check `rc.xml` is in the correct location

## Security Considerations

- The `IMGRES_AUTH` credential is passed via environment variable
- Consider using read-only filesystem for production deployments
- Physical access to the Pi grants full access to the system
- The kiosk runs with user privileges, not root

## Customization

To modify URLs or display assignments, edit the configuration section at the top of `imgres-launch-raspbian.sh`:
- `DISPLAY1` and `DISPLAY2` for monitor assignment
- URLs for each screen
- Window positions in `rc.xml` if using different resolution displays