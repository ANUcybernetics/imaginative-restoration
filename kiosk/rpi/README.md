# Raspberry Pi 5 kiosk setup

Scripts to flash an SD card so a Pi 5 boots directly into the Imaginative
Restoration dual-screen Chromium kiosk: display window on HDMI-A-1, capture
window on HDMI-A-2.

## Files

- `install-sdm.sh` — one-time installer for [SDM](https://github.com/gitbls/sdm)
  (the image-customisation tool we use to bake config into the SD card image).
- `pi-setup.sh` — main script. Downloads Raspberry Pi OS Bookworm, customises
  the image with all the kiosk plumbing, and writes it to an SD card.
- `imgres-launch-raspbian.sh` — legacy launcher from the old manual setup;
  kept for reference but `pi-setup.sh` no longer uses it (it writes a fresh
  `/usr/local/bin/imgres-kiosk-launch` to the image instead).
- `rc.xml` — legacy labwc config from the manual setup; superseded by the
  inline `~/.config/labwc/rc.xml` created during first boot.

## Usage

```bash
./install-sdm.sh                # once per host machine; requires sudo

./pi-setup.sh \
  --imgres-auth user:password \
  --hostname imgres-rpi \
  --wifi-ssid ANU-Secure \
  --wifi-enterprise-user SOCY2 \
  --wifi-enterprise-pass cybernetics2 \
  --tailscale-authkey tskey-auth-... \
  --ssh-key ~/.ssh/id_ed25519.pub
```

Run `./pi-setup.sh --help` for the full option list.

`--imgres-auth` is the only mandatory argument — it's the `user:password` for
HTTP basic auth on `imgres.fly.dev` (matches the `AUTH_USERNAME` / `AUTH_PASSWORD`
Fly secrets on the deployed app). Tailscale + WiFi are recommended; the SSH
key flag enables passwordless login.

## What ends up on the SD card

SDM customises the image before flashing, so the Pi boots ready to run.
Configuration baked in:

- **Admin account** (default `imgres / imgres`) with the supplied SSH key in
  `~/.ssh/authorized_keys`.
- **Hostname**, locale, timezone, keymap (timezone and locale inherited from
  the host running the flash; keymap is `us`).
- **Tailscale** — installed at first boot, then `tailscale up` runs as a
  one-shot systemd unit gated on `network-online.target`. Joins with `--ssh`
  so `tailscale ssh imgres@<hostname>` works from any tailnet device.
- **Enterprise WiFi** — written to `/etc/NetworkManager/system-connections/`
  by the first-boot script (regular WPA2 goes through SDM's `network` plugin
  instead, which baulks at 802.1X).
- **LightDM** autologin pinned to a custom `labwc-kiosk` Wayland session.
  We edit `/etc/lightdm/lightdm.conf` directly — Pi OS's
  `conf.d/` override mechanism is ignored for autologin.
- **Kiosk launcher** at `/usr/local/bin/imgres-kiosk-launch` plus the
  systemd user unit `imgres-kiosk.service`. The launcher opens two Chromium
  windows (with distinct `--class` values), and a daily timer restarts the
  service at midnight.
- **labwc window rules** that map each Chromium window's `app_id` to a
  specific HDMI output and toggle fullscreen — direct Wayland window
  placement isn't possible from the client side.
- **Chromium managed policy** at
  `/etc/chromium/policies/managed/imgres.json` granting camera/microphone
  access to the kiosk URL so Chromium doesn't show a permission prompt.

## Why a few non-obvious choices

- **`--disable-features=WebRtcPipeWireCamera`** on Chromium — Chromium 136
  on Wayland prefers the Pipewire+xdg-desktop-portal camera path, which
  silently hangs `getUserMedia` on this Pi/portal combo. Disabling forces
  V4L2 capture, which works.
- **`wait -n` in the launcher** — if either Chromium dies, we exit so
  systemd restarts the whole unit. A plain `wait` blocks forever on the
  survivor and leaves the kiosk in a broken half-state.
- **No `--use-fake-ui-for-media-stream`** — that flag works but Chromium
  shows a "you are using an unsupported flag" yellow infobar in kiosk mode.
  The managed policy file does the same job without the warning.
- **kiosk-config copied with `chown=imgres:imgres`** — file is mode 600 so
  it stays private, but the launcher runs as the kiosk user, not root.

## Day-to-day operation

```bash
# SSH in (over tailnet) once the Pi is up
tailscale ssh imgres@imgres-rpi

# Restart the kiosk after a config change
systemctl --user restart imgres-kiosk.service

# Live logs
journalctl --user -u imgres-kiosk -f

# Change the capture ROI without re-flashing
sudo kiosk-set-capture-box 150,0,410,280
systemctl --user restart imgres-kiosk

# Change the base URL (e.g. staging vs prod)
sudo kiosk-set-base-url https://staging.example.com
systemctl --user restart imgres-kiosk
```

## Troubleshooting

- **Black second monitor / both windows on one screen** — labwc didn't apply
  the window rule. Check `~/.config/labwc/rc.xml` exists and contains the
  `<windowRule identifier="chromium-browser-screen1|2">` blocks; the rule
  matches on Chromium's `--class` value as the Wayland `app_id`.
- **Pi boots to LXDE desktop, no kiosk** — autologin landed in
  `LXDE-pi-labwc` instead of `labwc-kiosk`. Check `/etc/lightdm/lightdm.conf`
  has `autologin-session=labwc-kiosk` (not just the `conf.d/` override).
- **Capture page shows no live webcam preview** — `chrome://policy` should
  list `VideoCaptureAllowedUrls` for the kiosk URL. If `getUserMedia` hangs,
  confirm `--disable-features=WebRtcPipeWireCamera` is on the Chromium
  command line.
- **Tailscale didn't join** — likely the auth key was burned/expired. Run
  `sudo tailscale up --authkey=<fresh-key> --ssh --hostname=$(hostname)`
  manually over LAN SSH; once joined it persists.
