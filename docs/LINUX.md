# Skeldri for Linux / Omarchy

This guide details how to build, install, and run the **Skeldri** (DrawPad) host daemon on Linux with Hyprland and Omarchy.

---

## Architecture Overview

The Linux daemon (`skeldri`) connects to the unmodified native iPadOS Skeldri app using Wire Protocol v2:

1. **Discovery**: Advertises `_drawpad._tcp` via **Avahi / mDNS** (port `52143` TCP, `protocol="2"`, and stable machine UUID).
2. **Control Channel**: Bi-directional JSON stream over TCP handling real-time vector stroke synchronization, display selection, ping/pong heartbeats, and canvas snapshots.
3. **Transparent Annotation Overlay**: Native Wayland layer-surface on the `Overlay` layer (`wlr-layer-shell`) with an empty input region (`wl_surface.set_input_region(None)`). This renders strokes with **100% click-through / mouse-transparent** pass-through to all desktop applications.
4. **Video Mirroring**: Real-time low-latency H.264 video pipeline (`libx264`, `profile=baseline`, `tune=zerolatency`, `bframes=0`, `keyint=60`, ~4 Mbps) packaged as AVCC access units with SPS/PPS parameter set extraction.
5. **Omarchy Integration**: QuickShell bar widget and popup drawer (`plugins/skeldri/`) for status monitoring and display switching directly from the desktop status bar.

---

## Requirements

- **OS**: Arch Linux / Omarchy (or any Wayland desktop supporting `wlr-layer-shell`).
- **Compositor**: Hyprland (recommended) or Sway.
- **Tools / Packages**:
  - `ffmpeg` (with `libx264`)
  - `avahi` (mDNS daemon running on LAN)
  - `rust` and `cargo` (for compilation)
  - `quickshell` (for Omarchy bar integration)

---

## Build & Installation

### Option 1: Arch Linux / Omarchy PKGBUILD (Recommended)

```bash
# Inside the skeldri project root
makepkg -si
```

This will:
- Compile the release binary into `/usr/bin/skeldri`.
- Install the `.desktop` launcher and systemd user service.
- Install the Omarchy QuickShell plugin to `/usr/share/omarchy/shell/plugins/skeldri/`.

### Option 2: Manual Cargo Build

```bash
cd linux/
cargo build --release
sudo install -Dm755 target/release/skeldri /usr/local/bin/skeldri
```

---

## Running the Daemon

### 1. Interactive / Terminal Launch
```bash
skeldri
```

### 2. Run as Systemd User Service
```bash
# Enable and start the daemon
systemctl --user enable --now skeldri.service

# Check status
systemctl --user status skeldri.service
```

---

## CLI Control Commands

The `skeldri` binary communicates with the running daemon over `/run/user/$UID/skeldri.sock`:

```bash
# View live status and connected device info
skeldri status

# Machine-readable JSON status (used by QuickShell / scripts)
skeldri status --json

# Clear all annotations on host and iPad
skeldri clear

# Toggle overlay visibility without clearing vector state
skeldri toggle

# Switch active display stream (e.g. display ID 1)
skeldri select-display 1

# Gracefully stop the background daemon
skeldri stop
```

---

## Network & Firewall Configuration

If an active firewall (`ufw`, `firewalld`, or `iptables`) is running, allow mDNS discovery and the TCP communication port:

### UFW:
```bash
sudo ufw allow 5353/udp comment 'mDNS Bonjour'
sudo ufw allow 52143/tcp comment 'Skeldri DrawPad'
```

### Firewalld:
```bash
sudo firewall-cmd --add-service=mdns --permanent
sudo firewall-cmd --add-port=52143/tcp --permanent
sudo firewall-cmd --reload
```

---

## Troubleshooting

### iPad does not discover the Linux machine
1. Ensure both devices are on the same local network subnet.
2. Check that Avahi is running: `systemctl status avahi-daemon`.
3. Test mDNS advertisement from terminal:
   ```bash
   avahi-browse -r _drawpad._tcp
   ```

### Screen mirroring is blank
1. Ensure `ffmpeg` with `libx264` is installed: `ffmpeg -encoders | grep libx264`.
2. Check daemon logs with: `journalctl --user -u skeldri.service -f` or run `skeldri` in terminal.
