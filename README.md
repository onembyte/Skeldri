# DrawPad

DrawPad turns an iPad into a wireless finger-annotation surface and opt-in trackpad for a Mac. It mirrors one selected Mac display over the local network while sending normalized vector strokes or relative pointer gestures on a separate low-latency channel. It requires neither Apple Pencil nor a cloud service.

> [!NOTE]
> DrawPad is a development-stage native Apple project. It has been exercised with a physical iPad, but it is not distributed through the App Store and still requires local Xcode signing.

## Features

- Automatic Mac discovery with Bonjour; no IP address configuration.
- Finger-first pen, highlighter, stroke eraser, color, thickness, undo, and clear.
- iPad-owned switching between attached Mac displays.
- Optional clearing of annotations when switching displays.
- Transparent, click-through Mac annotation overlay.
- Low-latency H.264 mirroring with stale-frame protection during display changes.
- Explicit Draw/Trackpad toggle, with pointer movement, tap, drag, two-finger scroll, and secondary click.
- Collapsible trackpad sensitivity, speed, and acceleration controls with persistent preferences.
- A top-left Back control that safely releases pointer state and returns to Mac discovery.
- Native Liquid Glass controls on current systems, with a material fallback on older supported iPadOS releases.
- Local-network-only operation with no accounts, telemetry, audio, or cloud backend.

## Requirements

- macOS 15 or later.
- iPadOS 18 or later.
- Xcode 27 beta or later for the currently checked-in project (Swift 6 and the current Liquid Glass SDK APIs).
- Mac and iPad connected to the same local network.
- XcodeGen only when regenerating `DrawPad.xcodeproj`; it is not needed for normal builds.

The reference development environment is recorded in [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

## Architecture

```text
ScreenCaptureKit → VideoToolbox → video TCP → iPad video layer
Finger → normalized vectors → control TCP → transparent Mac overlay
Trackpad gesture → validated relative event → control TCP → permission-gated Mac pointer
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
5. To use Trackpad mode, grant Pointer Control access from the menu-bar popover and follow the macOS prompt.

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

DrawPad advertises only `_drawpad._tcp` on the LAN. It has no internet relay, analytics, telemetry, authentication service, microphone access, camera access, or keyboard control. Trackpad mode uses macOS's permission-gated event-posting API; DrawPad cannot move the pointer until you explicitly approve it. V1 does not include pairing authentication, so use it only on a trusted local network. See [SECURITY.md](SECURITY.md).

## Project generation

`project.yml` is the source of truth for project structure. When XcodeGen is already installed:

```bash
xcodegen generate
```

Commit both `project.yml` and the regenerated `DrawPad.xcodeproj` when project structure changes.

## Documentation

- [Manual acceptance testing](docs/MANUAL_TESTING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Implementation status](docs/IMPLEMENTATION_STATUS.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

No open-source license has been selected yet. Until the repository owner adds one, the source remains under default copyright terms.
