# Development Environment

Inspected on 2026-08-10. No secrets or device identifiers are recorded.

| Component | Detected value |
|---|---|
| macOS | 27.0 (build 26A5388g) |
| CPU | Apple Silicon (`arm64`) |
| Xcode | 27.0 beta (build 27A5218g) |
| Developer directory | `/Applications/Xcode-beta.app/Contents/Developer` |
| Swift | 6.4 (`swiftlang-6.4.0.25.4`) |
| macOS SDK | 27.0 |
| iOS Simulator SDK | 27.0 |
| XcodeGen | `/opt/homebrew/bin/xcodegen` |
| Tuist | Not installed |

`simctl list devices available` failed because CoreSimulatorService/simdiskimaged was unavailable. Generic iOS Simulator builds can still validate compilation. `xcdevice` returned no usable physical-device listing during inspection, so physical iPad deployment remains a manual validation boundary.

