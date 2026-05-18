#!/bin/bash
# Raspberry Pi OS Bookworm automated SD card setup for an Imaginative
# Restoration dual-screen kiosk.
#
# Adapted from panic/rpi/pi-setup.sh. Two differences worth noting:
#   1. We bake in an HTTP-basic-auth credential (IMGRES_AUTH) and launch
#      two Chromium kiosk windows side-by-side — one for the display
#      (HDMI-A-1) and one for the capture view (HDMI-A-2, ?capture).
#   2. We deliberately omit --disable-gpu-driver-bug-workarounds /
#      --ignore-gpu-blocklist / --disable-features=UseChromeOSDirectVideoDecoder
#      that the old kiosk script had. Those forced V3D paths the blocklist
#      normally disables and are a plausible cause of the Pi 5 wedges we saw.

set -e
set -u
set -o pipefail

# Configuration
readonly RASPIOS_IMAGE_URL="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64.img.xz"
readonly DEFAULT_BASE_URL="https://imgres.fly.dev"
readonly CACHE_DIR="$HOME/.cache/raspios-images"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script is designed for Linux (Ubuntu)${NC}"
    exit 1
fi

check_required_tools() {
    local missing_tools=()
    for cmd in curl xz dd mktemp jq git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo "Install with: sudo apt-get install ${missing_tools[*]}"
        exit 1
    fi
}

check_sdm() {
    echo -e "${YELLOW}Checking for SDM installation...${NC}"
    if ! command -v sdm >/dev/null 2>&1; then
        echo -e "${RED}Error: SDM is not installed${NC}"
        echo "Run ./install-sdm.sh first."
        exit 1
    fi
    echo -e "${GREEN}✓ SDM is installed${NC}"
}

find_sd_card() {
    echo -e "${YELLOW}Looking for SD card devices...${NC}" >&2

    local devices=()
    local device_info=()

    while IFS= read -r line; do
        local device="/dev/$line"
        local removable=$(cat "/sys/block/$line/removable" 2>/dev/null || echo "0")
        local size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
        local size_gb=$((size / 1024 / 1024 / 1024))
        local model=$(lsblk -n -o MODEL "$device" 2>/dev/null | head -1 | tr -d ' ' || echo "Unknown")

        if [ "$removable" = "1" ] && [ "$size_gb" -ge 2 ] && [ "$size_gb" -le 256 ]; then
            devices+=("$device")
            device_info+=("${size_gb}GB - $model")
        fi
    done < <(ls /sys/block/ | grep -E '^(sd|mmcblk)[a-z0-9]*$')

    if [ ${#devices[@]} -eq 0 ]; then
        echo -e "${RED}Error: No SD card devices found${NC}" >&2
        return 1
    fi

    if [ ${#devices[@]} -eq 1 ]; then
        echo -e "${GREEN}✓ Found SD card at ${devices[0]} (${device_info[0]})${NC}" >&2
        echo "${devices[0]}"
        return 0
    fi

    echo -e "${YELLOW}Multiple removable devices found:${NC}" >&2
    for i in "${!devices[@]}"; do
        echo "  $((i+1))) ${devices[$i]} - ${device_info[$i]}" >&2
    done
    echo -n "Select device (1-${#devices[@]}): " >&2
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#devices[@]} ]; then
        echo -e "${GREEN}✓ Selected ${devices[$((selection-1))]} (${device_info[$((selection-1))]})${NC}" >&2
        echo "${devices[$((selection-1))]}"
        return 0
    else
        echo -e "${RED}Error: Invalid selection${NC}" >&2
        return 1
    fi
}

prepare_raspios_image() {
    local work_dir="$1"

    mkdir -p "$CACHE_DIR"

    local filename=$(basename "$RASPIOS_IMAGE_URL")
    local cached_compressed="$CACHE_DIR/$filename"
    local cached_img="${cached_compressed%.xz}"
    local work_img="$work_dir/raspios.img"

    if [ -f "$cached_img" ]; then
        echo -e "${GREEN}✓ Using cached image: $(basename "$cached_img")${NC}" >&2
        cp "$cached_img" "$work_img"
        echo "$work_img"
        return 0
    fi

    if [ -f "$cached_compressed" ]; then
        echo -e "${GREEN}✓ Found cached compressed image${NC}" >&2
    else
        echo -e "${YELLOW}Downloading Raspberry Pi OS image...${NC}" >&2
        if ! curl -L -o "$cached_compressed" "$RASPIOS_IMAGE_URL"; then
            echo -e "${RED}Error: Failed to download image${NC}" >&2
            rm -f "$cached_compressed"
            exit 1
        fi
    fi

    if ! file "$cached_compressed" | grep -q "XZ compressed data"; then
        echo -e "${RED}Error: Downloaded file is not a valid XZ compressed image${NC}" >&2
        rm -f "$cached_compressed"
        exit 1
    fi

    echo -e "${YELLOW}Decompressing image...${NC}" >&2
    xz -d -k -c "$cached_compressed" > "$cached_img"
    cp "$cached_img" "$work_img"
    echo -e "${GREEN}✓ Image ready for customization${NC}" >&2
    echo "$work_img"
}

write_image_to_sd() {
    local image_file="$1"
    local device="$2"
    local test_mode="${3:-false}"

    echo -e "${YELLOW}Writing customized image to SD card...${NC}"

    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping actual image write${NC}"
        return 0
    fi

    for part in "${device}"*; do
        if mountpoint -q "$part" 2>/dev/null; then
            sudo umount "$part" || true
        fi
    done

    sudo dd if="$image_file" of="$device" bs=4M status=progress oflag=direct
    sudo sync
    echo -e "${GREEN}✓ Image written to SD card${NC}"
    sudo partprobe "$device" || true
    sleep 2
}

create_sdm_customization() {
    local work_dir="$1"
    local base_url="$2"
    local capture_box="$3"
    local hostname="$4"
    local username="$5"
    local imgres_auth="$6"
    local wifi_ssid="$7"
    local wifi_password="$8"
    local wifi_enterprise_user="$9"
    local wifi_enterprise_pass="${10}"
    local tailscale_authkey="${11}"

    echo -e "${YELLOW}Creating SDM customization scripts...${NC}"

    local plugin_dir="$work_dir/plugins"
    mkdir -p "$plugin_dir"

    cat > "$plugin_dir/kiosk-setup.sh" << 'KIOSK_SCRIPT'
#!/bin/bash
# Imaginative Restoration kiosk setup — runs at first boot.

set +e
echo "Starting Imaginative Restoration kiosk setup at first boot..."
exec 2>&1

if [ -f /usr/local/sdm/kiosk-config ]; then
    source /usr/local/sdm/kiosk-config
fi

KIOSK_BASE_URL="${KIOSK_BASE_URL:-https://imgres.fly.dev}"
KIOSK_CAPTURE_BOX="${KIOSK_CAPTURE_BOX:-}"
KIOSK_HOSTNAME="${KIOSK_HOSTNAME:-imgres-rpi}"
KIOSK_USERNAME="${KIOSK_USERNAME:-imgres}"

echo "Adding user to required groups..."
usermod -a -G video,render,input,audio,tty "$KIOSK_USERNAME" || true

USER_HOME="/home/$KIOSK_USERNAME"

# labwc config
mkdir -p "$USER_HOME/.config/labwc"

cat > "$USER_HOME/.config/labwc/autostart" << 'EOF'
# Hide cursor by overwriting the cursor image (unclutter doesn't work on Wayland).
if [ -f /usr/share/icons/PiXflat/cursors/left_ptr ]; then
    sudo mv /usr/share/icons/PiXflat/cursors/left_ptr /usr/share/icons/PiXflat/cursors/left_ptr.bak
fi

systemctl --user start imgres-kiosk.service &
EOF
chmod +x "$USER_HOME/.config/labwc/autostart"

cat > "$USER_HOME/.config/labwc/rc.xml" << 'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <decoration>no</decoration>
    <gap>0</gap>
  </core>
  <keyboard>
    <keybind key="Super-q">
      <action name="Exit"/>
    </keybind>
  </keyboard>
  <!-- Chromium starts fullscreen via --kiosk on whatever output labwc places
       it on. MoveToOutput refuses to act on fullscreen windows, so we
       toggle-off, move, toggle-on. matchOnce avoids re-firing on Chromium's
       internal pop-up windows. -->
  <windowRules>
    <windowRule identifier="chromium-browser-screen1" matchOnce="true">
      <action name="ToggleFullscreen"/>
      <action name="MoveToOutput" output="HDMI-A-1"/>
      <action name="ToggleFullscreen"/>
    </windowRule>
    <windowRule identifier="chromium-browser-screen2" matchOnce="true">
      <action name="ToggleFullscreen"/>
      <action name="MoveToOutput" output="HDMI-A-2"/>
      <action name="ToggleFullscreen"/>
    </windowRule>
  </windowRules>
</labwc_config>
EOF

mkdir -p "$USER_HOME/.config/systemd/user/default.target.wants"
mkdir -p "$USER_HOME/.config/systemd/user/timers.target.wants"

# The launcher that brings up both Chromium kiosk windows.
cat > /usr/local/bin/imgres-kiosk-launch << 'EOF'
#!/bin/bash
# Launch the imgres dual-screen kiosk. Reads config from
# /usr/local/sdm/kiosk-config (baked in by SDM at flash time).

set -u

if [ -f /usr/local/sdm/kiosk-config ]; then
    # shellcheck disable=SC1091
    source /usr/local/sdm/kiosk-config
fi

BASE_URL="${KIOSK_BASE_URL:-https://imgres.fly.dev}"
CAPTURE_BOX="${KIOSK_CAPTURE_BOX:-}"

if [ -z "${IMGRES_AUTH:-}" ]; then
    echo "Error: IMGRES_AUTH not set in /usr/local/sdm/kiosk-config" >&2
    exit 1
fi

# Build URLs with basic-auth embedded. The display window gets /, the
# capture window gets /?capture (plus optional capture_box for ROI tuning).
PROTO="${BASE_URL%%://*}"
HOST="${BASE_URL#*://}"
DISPLAY_URL="${PROTO}://${IMGRES_AUTH}@${HOST}/"
if [ -n "$CAPTURE_BOX" ]; then
    CAPTURE_URL="${PROTO}://${IMGRES_AUTH}@${HOST}/?capture_box=${CAPTURE_BOX}"
else
    CAPTURE_URL="${PROTO}://${IMGRES_AUTH}@${HOST}/?capture"
fi

# Clean only OUR chromium instances; don't touch the user's stray windows.
pkill -f "chromium.*--user-data-dir=/tmp/chromium_screen" || true
sleep 1

# Notes on the flags below:
#   * --window-position / --window-size are ignored under Wayland — placement
#     is handled by the labwc windowRules in ~/.config/labwc/rc.xml.
#   * --disable-features=WebRtcPipeWireCamera forces V4L2 capture instead of
#     Pipewire+xdg-desktop-portal; on Pi 5 / Chromium 136 the portal path
#     hangs getUserMedia silently with no error.
#   * Camera permission is granted to imgres.fly.dev via the managed policy
#     in /etc/chromium/policies/managed/imgres.json, so we don't need any
#     test-only flag like --use-fake-ui-for-media-stream (which shows a
#     yellow "unsupported flag" infobar in recent Chromium).
#   * We deliberately omit --disable-gpu-driver-bug-workarounds /
#     --ignore-gpu-blocklist / --disable-features=UseChromeOSDirectVideoDecoder
#     that the old kiosk script had — they forced V3D paths the blocklist
#     normally disables and are a plausible cause of Pi 5 wedges.
COMMON=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --disable-translate
    --disable-pinch
    --disable-component-update
    --no-first-run
    --check-for-update-interval=31536000
    --enable-features=OverlayScrollbar
    --disable-features=WebRtcPipeWireCamera
    --ozone-platform=wayland
    --autoplay-policy=no-user-gesture-required
)

chromium-browser \
    "${COMMON[@]}" \
    --class=chromium-browser-screen1 \
    --user-data-dir=/tmp/chromium_screen1 \
    "$DISPLAY_URL" >/dev/null 2>&1 &

sleep 2

chromium-browser \
    "${COMMON[@]}" \
    --class=chromium-browser-screen2 \
    --user-data-dir=/tmp/chromium_screen2 \
    "$CAPTURE_URL" >/dev/null 2>&1 &

# Exit as soon as either child dies so systemd restarts the whole unit
# (otherwise a dead screen2 leaves us blocked on wait forever).
wait -n
EOF
chmod +x /usr/local/bin/imgres-kiosk-launch

cat > "$USER_HOME/.config/systemd/user/imgres-kiosk.service" << 'EOF'
[Unit]
Description=Imaginative Restoration dual-screen Chromium kiosk
After=graphical-session.target
Requires=graphical-session.target

[Service]
Type=simple
Environment="WAYLAND_DISPLAY=wayland-0"
ExecStartPre=/bin/bash -c 'while [ ! -S "/run/user/$(id -u)/${WAYLAND_DISPLAY}" ]; do sleep 0.5; done'
ExecStart=/usr/local/bin/imgres-kiosk-launch
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

cat > "$USER_HOME/.config/systemd/user/imgres-kiosk-restart.service" << 'EOF'
[Unit]
Description=Restart Imaginative Restoration kiosk
Requires=imgres-kiosk.service

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --user restart imgres-kiosk.service
EOF

cat > "$USER_HOME/.config/systemd/user/imgres-kiosk-restart.timer" << 'EOF'
[Unit]
Description=Restart Imaginative Restoration kiosk at midnight daily
Requires=imgres-kiosk.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF

ln -sf "../imgres-kiosk.service" "$USER_HOME/.config/systemd/user/default.target.wants/"
ln -sf "../imgres-kiosk-restart.timer" "$USER_HOME/.config/systemd/user/timers.target.wants/"

chown -R "$KIOSK_USERNAME:$KIOSK_USERNAME" "$USER_HOME/.config"

cat > /usr/share/wayland-sessions/labwc-kiosk.desktop << EOF
[Desktop Entry]
Name=Labwc Kiosk
Comment=Labwc compositor in kiosk mode
Exec=/usr/local/bin/labwc-kiosk-session.sh
Type=Application
DesktopNames=Labwc
EOF

cat > /usr/local/bin/labwc-kiosk-session.sh << 'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_CLASS=user
export XDG_CURRENT_DESKTOP=Labwc
exec labwc
EOF
chmod +x /usr/local/bin/labwc-kiosk-session.sh

# Convenience: kiosk-set-url base | capture_box edits
cat > /usr/local/bin/kiosk-set-base-url << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: kiosk-set-base-url <base-url>"
    grep ^KIOSK_BASE_URL /usr/local/sdm/kiosk-config 2>/dev/null || echo "Not set"
    exit 1
fi
sudo sed -i "s|^KIOSK_BASE_URL=.*|KIOSK_BASE_URL=\"$1\"|" /usr/local/sdm/kiosk-config
echo "✓ Base URL updated. systemctl --user restart imgres-kiosk to apply."
EOF
chmod +x /usr/local/bin/kiosk-set-base-url

cat > /usr/local/bin/kiosk-set-capture-box << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: kiosk-set-capture-box <x,y,w,h>   (empty string to clear)"
    grep ^KIOSK_CAPTURE_BOX /usr/local/sdm/kiosk-config 2>/dev/null || echo "Not set"
    exit 1
fi
sudo sed -i "s|^KIOSK_CAPTURE_BOX=.*|KIOSK_CAPTURE_BOX=\"$1\"|" /usr/local/sdm/kiosk-config
echo "✓ Capture box updated. systemctl --user restart imgres-kiosk to apply."
EOF
chmod +x /usr/local/bin/kiosk-set-capture-box

# Autologin session selection. Pi OS Bookworm ships /etc/lightdm/lightdm.conf
# with autologin-session=LXDE-pi-labwc, and the conf.d/ override is NOT
# honoured for autologin (verified on 2025-05-13 image) — so edit the main
# file in place. We rewrite both autologin-session and user-session.
sed -i "s|^autologin-session=.*|autologin-session=labwc-kiosk|;
        s|^user-session=.*|user-session=labwc-kiosk|" /etc/lightdm/lightdm.conf

# Grant imgres.fly.dev camera access without prompting. Replaces the older
# trick of passing --use-fake-ui-for-media-stream (which Chromium now flags
# as unsupported with a yellow infobar).
mkdir -p /etc/chromium/policies/managed
cat > /etc/chromium/policies/managed/imgres.json << EOF
{
  "VideoCaptureAllowedUrls": ["$KIOSK_BASE_URL"],
  "AudioCaptureAllowedUrls": ["$KIOSK_BASE_URL"]
}
EOF

# .dmrc is a FILE, not a directory — earlier panic-derived version did
# `mkdir -p ~/.dmrc` first, leaving an empty directory that LightDM ignored.
cat > "$USER_HOME/.dmrc" << EOF
[Desktop]
Session=labwc-kiosk
EOF
chown "$KIOSK_USERNAME:$KIOSK_USERNAME" "$USER_HOME/.dmrc"

systemctl set-default graphical.target
systemctl enable lightdm.service

# Enterprise WiFi NM connection (regular WPA2 is handled by SDM's network plugin).
if [ -n "${WIFI_SSID:-}" ] && [ -n "${WIFI_ENTERPRISE_USER:-}" ] && [ -n "${WIFI_ENTERPRISE_PASS:-}" ]; then
    echo "Configuring enterprise WiFi..."
    rfkill unblock wifi || true
    raspi-config nonint do_wifi_country AU || true

    cat > "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection" << EOF
[connection]
id=${WIFI_SSID}
uuid=$(uuidgen)
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=${WIFI_SSID}

[wifi-security]
key-mgmt=wpa-eap

[802-1x]
eap=peap
identity=${WIFI_ENTERPRISE_USER}
password=${WIFI_ENTERPRISE_PASS}
phase2-auth=mschapv2

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    chmod 600 "/etc/NetworkManager/system-connections/${WIFI_SSID}.nmconnection"
fi

echo "Imaginative Restoration kiosk-setup plugin completed!"
KIOSK_SCRIPT

    chmod +x "$plugin_dir/kiosk-setup.sh"

    cat > "$plugin_dir/kiosk-config" << EOF
# Imaginative Restoration kiosk configuration (baked in at flash time).
KIOSK_BASE_URL="$base_url"
KIOSK_CAPTURE_BOX="$capture_box"
KIOSK_HOSTNAME="$hostname"
KIOSK_USERNAME="$username"
IMGRES_AUTH="$imgres_auth"
WIFI_SSID="$wifi_ssid"
WIFI_PASSWORD="$wifi_password"
WIFI_ENTERPRISE_USER="$wifi_enterprise_user"
WIFI_ENTERPRISE_PASS="$wifi_enterprise_pass"
TAILSCALE_AUTHKEY="$tailscale_authkey"
EOF
    chmod 600 "$plugin_dir/kiosk-config"

    if [ -n "$tailscale_authkey" ]; then
        cat > "$plugin_dir/tailscale-setup.sh" << 'TAILSCALE_SCRIPT'
#!/bin/bash
# Tailscale setup — runs at first boot.

set -e
echo "Starting Tailscale setup at first boot..."
curl -fsSL https://tailscale.com/install.sh | sh

cat > /etc/systemd/system/tailscale-join.service << 'EOF'
[Unit]
Description=Join Tailscale Network
After=network-online.target tailscaled.service
Wants=network-online.target
ConditionPathExists=!/var/lib/tailscale/.setup-complete

[Service]
Type=oneshot
EnvironmentFile=/usr/local/sdm/kiosk-config
ExecStartPre=/bin/bash -c 'test -n "${TAILSCALE_AUTHKEY}"'
ExecStart=/usr/bin/tailscale up --authkey=${TAILSCALE_AUTHKEY} --ssh --hostname=${KIOSK_HOSTNAME} --accept-routes --accept-dns=false
ExecStartPost=/bin/mkdir -p /var/lib/tailscale
ExecStartPost=/bin/touch /var/lib/tailscale/.setup-complete
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable tailscale-join.service
echo "Tailscale setup completed!"
TAILSCALE_SCRIPT
        chmod +x "$plugin_dir/tailscale-setup.sh"
    fi

    echo -e "${GREEN}✓ SDM customization scripts created${NC}"
}

run_sdm_customization() {
    local work_dir="$1"
    local image_file="$2"
    local hostname="$3"
    local username="$4"
    local password="$5"
    local wifi_ssid="$6"
    local wifi_password="$7"
    local wifi_enterprise_user="$8"
    local wifi_enterprise_pass="$9"
    local tailscale_authkey="${10}"
    local ssh_key_file="${11}"
    local test_mode="${12:-false}"

    echo -e "${YELLOW}Running SDM customization...${NC}"

    if [ "$test_mode" = "true" ]; then
        echo -e "${YELLOW}TEST MODE: Skipping SDM customization${NC}"
        echo "Would customize image with:"
        echo "  Hostname: $hostname"
        echo "  Username: $username"
        echo "  WiFi SSID: ${wifi_ssid:-<none>}"
        echo "  Tailscale: $([ -n "$tailscale_authkey" ] && echo configured || echo none)"
        return 0
    fi

    local sdm_keymap="us"
    local sdm_locale="$(locale | grep LANG= | cut -d= -f2 | tr -d '"' || echo 'en_US.UTF-8')"
    local sdm_timezone="$(timedatectl show --property=Timezone --value 2>/dev/null || echo 'UTC')"

    echo "Using host locale: $sdm_locale"
    echo "Using host timezone: $sdm_timezone"

    local plugin_args=()
    plugin_args+=("--plugin" "user:adduser=$username|password=$password")
    plugin_args+=("--plugin" "raspiconfig:boot_behaviour=B4")
    plugin_args+=("--plugin" "L10n:keymap=$sdm_keymap|locale=$sdm_locale|timezone=$sdm_timezone")

    if [ -n "$wifi_ssid" ] && [ -z "$wifi_enterprise_user" ]; then
        plugin_args+=("--plugin" "network:wifissid=$wifi_ssid|wifipassword=$wifi_password|wificountry=AU")
    fi

    plugin_args+=("--plugin" "apps:apps=jq,curl,uuid-runtime")

    if [ -n "$ssh_key_file" ] && [ -f "$ssh_key_file" ]; then
        # SDM ≥ 15: import-pubkey adds the public key to <sshuser>'s authorized_keys
        plugin_args+=("--plugin" "sshkey:sshuser=$username|import-pubkey=$ssh_key_file")
    fi

    plugin_args+=("--plugin" "runatboot:script=$work_dir/plugins/kiosk-setup.sh|output")
    if [ -n "$tailscale_authkey" ]; then
        plugin_args+=("--plugin" "runatboot:script=$work_dir/plugins/tailscale-setup.sh|output")
    fi

    # Owned by the kiosk user so the unprivileged launcher can read IMGRES_AUTH.
    # File is mode 600 already; ownership by imgres keeps it private to that user.
    plugin_args+=("--plugin" "copyfile:from=$work_dir/plugins/kiosk-config|to=/usr/local/sdm/|chown=$username:$username")

    sudo sdm \
        --customize \
        --batch \
        --host "$hostname" \
        "${plugin_args[@]}" \
        --plugin disables:piwiz \
        --plugin system:service-enable=ssh,sdm-firstboot \
        --regen-ssh-host-keys \
        --expand-root \
        --restart \
        --apt-options none \
        "$image_file"

    echo -e "${GREEN}✓ SDM customization complete${NC}"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required:
    --imgres-auth <user:pass>      HTTP basic-auth for imgres.fly.dev

Configuration:
    --base-url <url>               Base URL (default: $DEFAULT_BASE_URL)
    --capture-box <x,y,w,h>        Optional capture ROI (default: full frame)
    --hostname <name>              Pi hostname (default: imgres-rpi)
    --username <user>              Admin account name (default: imgres)
    --password <pass>              Admin account password (default: imgres)

Network (optional):
    --wifi-ssid <ssid>             WiFi network name
    --wifi-password <pass>         WiFi password (WPA2-PSK)
    --wifi-enterprise-user <u>     Enterprise WiFi username
    --wifi-enterprise-pass <p>     Enterprise WiFi password
    --tailscale-authkey <key>      Tailscale auth key

Other:
    --ssh-key <path>               SSH public key for passwordless login
    --test                         Test mode (no SD card write)
EOF
    exit 1
}

main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    local base_url="$DEFAULT_BASE_URL"
    local capture_box=""
    local imgres_auth=""
    local wifi_ssid=""
    local wifi_password=""
    local wifi_enterprise_user=""
    local wifi_enterprise_pass=""
    local hostname="imgres-rpi"
    local username="imgres"
    local password="imgres"
    local tailscale_authkey=""
    local ssh_key_file=""
    local test_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --base-url) base_url="$2"; shift 2 ;;
            --capture-box) capture_box="$2"; shift 2 ;;
            --imgres-auth) imgres_auth="$2"; shift 2 ;;
            --wifi-ssid) wifi_ssid="$2"; shift 2 ;;
            --wifi-password) wifi_password="$2"; shift 2 ;;
            --wifi-enterprise-user) wifi_enterprise_user="$2"; shift 2 ;;
            --wifi-enterprise-pass) wifi_enterprise_pass="$2"; shift 2 ;;
            --hostname) hostname="$2"; shift 2 ;;
            --username) username="$2"; shift 2 ;;
            --password) password="$2"; shift 2 ;;
            --tailscale-authkey) tailscale_authkey="$2"; shift 2 ;;
            --ssh-key) ssh_key_file="$2"; shift 2 ;;
            --test) test_mode=true; shift ;;
            --help) usage ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
        esac
    done

    local errors=()
    [ -z "$imgres_auth" ] && errors+=("--imgres-auth is required")
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ] || [ -n "$wifi_enterprise_pass" ]; then
            [ -z "$wifi_enterprise_user" ] && errors+=("--wifi-enterprise-user required for enterprise WiFi")
            [ -z "$wifi_enterprise_pass" ] && errors+=("--wifi-enterprise-pass required for enterprise WiFi")
        else
            [ -z "$wifi_password" ] && errors+=("--wifi-password required for WPA2-PSK networks")
        fi
    fi
    if [ -n "$ssh_key_file" ] && [ ! -f "$ssh_key_file" ]; then
        errors+=("SSH key file not found: $ssh_key_file")
    fi
    if ! [[ "$base_url" =~ ^https?:// ]]; then
        errors+=("Invalid base URL: $base_url")
    fi
    if [ ${#errors[@]} -gt 0 ]; then
        echo -e "${RED}Error: invalid arguments:${NC}"
        for e in "${errors[@]}"; do echo "  - $e"; done
        usage
    fi

    if [ "$test_mode" != "true" ]; then
        check_required_tools
    fi

    echo -e "${GREEN}Imaginative Restoration Pi 5 kiosk SD card setup${NC}"
    echo "================================================="
    echo "  Hostname:     $hostname"
    echo "  Username:     $username"
    echo "  Base URL:     $base_url"
    echo "  Capture box:  ${capture_box:-<full frame>}"
    echo "  IMGRES_AUTH:  ${imgres_auth%%:*}:***"
    if [ -n "$wifi_ssid" ]; then
        if [ -n "$wifi_enterprise_user" ]; then
            echo "  WiFi:         enterprise — $wifi_ssid ($wifi_enterprise_user)"
        else
            echo "  WiFi:         WPA2 — $wifi_ssid"
        fi
    else
        echo "  WiFi:         not configured (ethernet only)"
    fi
    echo "  Tailscale:    $([ -n "$tailscale_authkey" ] && echo Configured || echo "Not configured")"
    echo "  SSH key:      $([ -f "$ssh_key_file" ] && echo "$ssh_key_file" || echo "Not configured")"
    echo "  Test mode:    $test_mode"
    echo

    local device
    if [ "$test_mode" = "true" ]; then
        device="/dev/test"
    else
        device=$(find_sd_card)
        [ -z "$device" ] && exit 1
    fi

    if [ "$test_mode" != "true" ]; then
        local device_size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -1 || echo "0")
        local device_size_gb=$((device_size / 1024 / 1024 / 1024))
        local device_model=$(lsblk -n -o MODEL "$device" 2>/dev/null | tr -d ' ' || echo "Unknown")

        echo -e "${YELLOW}WARNING: this will ERASE all data on $device${NC}"
        echo -e "${YELLOW}Device: $device - ${device_size_gb}GB - $device_model${NC}"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
        check_sdm
    fi

    local work_dir=$(mktemp -d -t imgres-setup-XXXXX)
    echo -e "${YELLOW}Using work directory: $work_dir${NC}"

    local image_file
    image_file=$(prepare_raspios_image "$work_dir")

    create_sdm_customization "$work_dir" "$base_url" "$capture_box" \
        "$hostname" "$username" "$imgres_auth" \
        "$wifi_ssid" "$wifi_password" "$wifi_enterprise_user" \
        "$wifi_enterprise_pass" "$tailscale_authkey"

    run_sdm_customization "$work_dir" "$image_file" \
        "$hostname" "$username" "$password" \
        "$wifi_ssid" "$wifi_password" "$wifi_enterprise_user" \
        "$wifi_enterprise_pass" "$tailscale_authkey" \
        "$ssh_key_file" "$test_mode"

    if [ "$test_mode" != "true" ]; then
        write_image_to_sd "$image_file" "$device" "$test_mode"
        rm -rf "$work_dir"
        echo -e "${GREEN}✓ SD card ready.${NC}"
    else
        echo -e "${YELLOW}TEST MODE artefacts in: $work_dir${NC}"
        ls -la "$work_dir/plugins/"
    fi

    echo
    echo "Next steps:"
    echo "  1. Insert the SD card into the Pi 5"
    echo "  2. Connect both HDMI displays (display = HDMI-A-1, capture = HDMI-A-2)"
    echo "  3. Power on. First boot takes 2-3 min while WiFi/Tailscale/kiosk configure."
    if [ -n "$tailscale_authkey" ]; then
        echo "  4. From your laptop: tailscale ssh $username@$hostname"
        echo "     Then: journalctl --user -u imgres-kiosk -f"
    else
        echo "  4. SSH (LAN): ssh $username@<pi-ip>"
    fi
}

main "$@"
