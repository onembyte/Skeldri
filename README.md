# DrawPad (Skeldri)

DrawPad turns an iPad into a wireless drawing and finger-annotation surface for **Linux (Omarchy / Hyprland)** and **macOS**. It mirrors one selected display over the local network while sending normalized vector strokes on a separate low-latency channel, so annotations appear immediately on both devices. It requires neither Apple Pencil nor a cloud service and never controls mouse or keyboard input.

---

## ⚡ Quick Install (Linux / Omarchy)

Install the `skeldri` daemon, systemd user service, and Omarchy QuickShell bar plugin with one command:

```bash
curl -fsSL https://onembyte.github.io/Skeldri/install.sh | bash
```

> *(Fallback via raw GitHub)*:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/onembyte/Skeldri/main/scripts/install.sh | bash
> ```

🌐 **Landing Page & Live Demo**: [https://onembyte.github.io/Skeldri](https://onembyte.github.io/Skeldri)
🐧 **Linux & Omarchy Guide**: [docs/LINUX.md](docs/LINUX.md)

---

## Features

- **Automatic Discovery**: Bonjour / Avahi mDNS discovery (`_drawpad._tcp`); zero IP configuration.
- **100% Click-Through Overlay**: Native Wayland (`wlr-layer-shell`) and macOS transparent overlays with empty input regions so you can interact with desktop windows underneath.
- **Low-Latency H.264 Mirroring**: Real-time 30 FPS video streaming with stale-frame drop protection.
- **Finger & Stylus Inking**: Pen, highlighter, stroke eraser, custom colors, normalized stroke thickness, undo, and clear.
- **Multi-Monitor Switching**: iPad-owned or desktop-owned switching between attached displays.
- **Omarchy Shell Integration**: Native QuickShell top-bar widget and control panel.
- **Local & Private**: Pure local-network operation with zero cloud relays, accounts, telemetry, or tracking.

## Requirements

- **Linux**: Arch Linux / Omarchy with Hyprland or Wayland (supports `wlr-layer-shell`), `ffmpeg`, and `avahi`.
- **macOS**: macOS 15 or later.
- **iPadOS**: iPadOS 18 or later.
- **Local Network**: Host and iPad connected to the same local Wi-Fi / subnet.

The reference development environment is recorded in [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

## Architecture

```text
ScreenCaptureKit → VideoToolbox → video TCP → iPad video layer
Finger → normalized vectors → control TCP → transparent Mac overlay
```

Video and drawing state remain independent, preventing the Mac overlay from being recursively captured and keeping finger feedback responsive when video is delayed. See [Architecture](docs/ARCHITECTURE.md), [Clean Architecture](docs/CLEAN_ARCHITECTURE.md), and [Wire Protocol](docs/PROTOCOL.md).

## Build and test

```bash
./scripts/doctor.sh
./scripts/build.sh
./scripts/test.sh
```

All DerivedData produced by these scripts stays in `.build/DerivedData`.

## Run on a Mac

1. Open `DrawPad.xcodeproj`.
2. Select the `DrawPadMac` scheme and **My Mac** destination.
3. Run the app.
4. Grant Screen Recording access when prompted, then relaunch if macOS requests it.

## Run on iPad Simulator

Select the `DrawPadiPad` scheme, choose an installed iPad simulator, and run. Discovery and physical network behavior are best validated on a real iPad.

## Run on a physical iPad

1. Enable **Settings → Privacy & Security → Developer Mode** on iPad and complete its requested restart.
2. Connect the iPad over USB and trust the Mac if prompted.
3. In **DrawPadiPad → Signing & Capabilities**, enable automatic signing and choose your Apple Development Team. No Team ID is committed to this repository.
4. Select the connected iPad as the run destination and press Run.
5. Permit Local Network access when prompted.
6. If iPadOS blocks the first launch, trust the developer under **Settings → General → VPN & Device Management**.

### Personal installation without opening Xcode

After selecting your free Personal Team in Xcode once, you can build, install, package, and launch both apps from Terminal:

```bash
./scripts/install-personal.sh --team YOUR_TEAM_ID --device "Your iPad Name"
```

The script remembers those two values only inside the ignored `.build` directory. Future refreshes are one command:

```bash
./scripts/install-personal.sh
```

The optimized Mac app and its ZIP archive are written to `.build/PersonalInstall`. The iPad app behaves like a normal installed app while its provisioning profile is valid. Apple free Personal Team profiles expire after 7 days, so rerun the command weekly. Xcode must remain installed for its compiler, signing, and device tools, but it does not need to be open during normal use or refreshes.

## Privacy and security

DrawPad advertises only `_drawpad._tcp` on the LAN. It has no internet relay, analytics, telemetry, authentication service, microphone access, camera access, or Accessibility permission. V1 does not include pairing authentication, so use it only on a trusted local network. See [SECURITY.md](SECURITY.md).

## Project generation

`project.yml` is the source of truth for project structure. When XcodeGen is already installed:

```bash
xcodegen generate
```

Commit both `project.yml` and the regenerated `DrawPad.xcodeproj` when project structure changes.

## Documentation

- [Linux / Omarchy Guide](docs/LINUX.md)
- [Manual acceptance testing](docs/MANUAL_TESTING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Implementation status](docs/IMPLEMENTATION_STATUS.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

No open-source license has been selected yet. Until the repository owner adds one, the source remains under default copyright terms.
