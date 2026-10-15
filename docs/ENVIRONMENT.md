# Reference Development Environment

Inspected on 2026-10-10. No secrets or device identifiers are recorded.

| Component | Detected value |
|---|---|
| macOS | 27.2 beta 3 (build 26B5101f) |
| CPU | Apple Silicon (`arm64`) |
| Xcode | 27.1 Release Candidate (build 27A9275), the App Store build toolchain |
| Developer directory | `/Applications/Xcode.app/Contents/Developer` |
| Swift | 6.4 (`swiftlang-6.4.0.34.1`) |
| macOS SDK | 27.0 |
| iOS SDK / iOS Simulator SDK | 27.1 |
| iOS Simulator runtime | iOS 27.1 (24A94232) only |
| XcodeGen | 2.46.0 at `/opt/homebrew/bin/xcodegen`; reproduces the committed project exactly |
| Tuist | Not installed |

On this toolchain, `./scripts/test.sh` passes 83 tests in 20 suites, `./scripts/build.sh` builds both apps, and `./scripts/release-audit.sh` passes. Disk space is tight on this Mac: keep a single simulator runtime and offload stale build output to the TrueNAS share.

History: the August 2026 work used Xcode 27.0 beta (27A5218g) on macOS 27.0 beta. Builds from a beta Xcode cannot be uploaded to App Store Connect, so that toolchain was retired.

The initial `simctl` inspection failed because CoreSimulatorService/simdiskimaged was unavailable; it recovered during Xcode build validation. A USB iPad (7th generation, iPadOS 18.6.2) was subsequently used for signed installation and runtime validation; no device identifier is recorded here.
