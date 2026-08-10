# DrawPad

DrawPad turns an iPad into a local-network finger annotation surface for a Mac: the Mac display is mirrored to the iPad while normalized vector strokes render immediately on both devices. It requires neither Apple Pencil nor a cloud service and does not control mouse or keyboard input.

## Requirements

The project is currently validated against Xcode 27/Swift 6.4 with macOS and iPadOS 27 SDKs. Deployment targets are macOS 15 and iPadOS 18.

## Architecture

`ScreenCaptureKit → VideoToolbox → video TCP → iPad video layer`

`Finger → normalized vectors → control TCP → transparent Mac overlay`

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/CLEAN_ARCHITECTURE.md](docs/CLEAN_ARCHITECTURE.md).

## Build and test

```bash
./scripts/doctor.sh
./scripts/build.sh
./scripts/test.sh
```

Open `DrawPad.xcodeproj`, choose DrawPadMac and **My Mac**, then Run. For iPad Simulator, select DrawPadiPad and an installed iPad simulator. For a physical iPad, select the target, enable Automatically manage signing, choose your Team, select the connected iPad, and Run.

Grant Screen Recording to the Mac app and Local Network access to the iPad when prompted. See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) and [docs/MANUAL_TESTING.md](docs/MANUAL_TESTING.md).
