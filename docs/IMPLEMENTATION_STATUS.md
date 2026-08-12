# Implementation Status

| Milestone | Status |
|---|---|
| 0 — Environment/governance | Complete |
| 1 — Project scaffold | Complete; both targets compile |
| 2 — Shared drawing model | Complete; automated tests pass |
| 3 — Mac overlay | Physical-device drawing, clear, undo, and erasing validated |
| 4 — Mac screen capture | SCStream plus first-frame ScreenCaptureKit fallback implemented; encoded output verified at runtime |
| 5 — Network discovery/control | Bonjour discovery and dual-channel connection validated on physical iPad |
| 6 — Finger drawing synchronization | Finger-to-iPad-to-Mac overlay validated on physical iPad |
| 7 — H.264 encoding | Implemented; outgoing encoded traffic verified at runtime |
| 8 — Video transport | Implemented; sustained video-channel byte flow verified |
| 9 — iPad video decoder | Implemented and visually validated on a physical iPad |
| 10 — Composite video + annotation | Video, annotation alignment, and display switching validated on physical displays |
| 11 — Toolbar | Implemented and installed, including direct clear and active-tool indicators |
| 12 — Resilience | Display switching, reconnect, bounded low-latency video recovery, and trackpad fail-safe release hardened; complete acceptance sweep remains ongoing |
| 13 — Documentation and cleanup | Complete for development-stage publication |

A USB iPad (7th generation, iPadOS 18.6.2) was used for validation. Signed builds install and launch successfully. Bonjour discovery, connection, video mirroring, drawing synchronization, destructive drawing actions, and repeated display switching have been exercised. Display switching serializes capture lifecycle operations, coalesces rapid requests, confirms selection from the Mac, and rejects video frames from obsolete encoder generations. Protocol 6 retains bounded video recovery and sequenced, validated trackpad movement, scroll, click, drag, and accumulated pinch-zoom events, while adding session-bound channels and explicit Mac-side authorization before video or input. Background, Back-navigation, rejection, timeout, and disconnect paths release pointer and connection state idempotently. The current automated suite contains 40 tests; a final physical acceptance sweep of the release-candidate authorization flow remains open.

Lecture mode remains design-only. After an interrupted model-switch session, both
repositories were verified clean and the 40-test modern baseline passed. Full app
build validation is temporarily gated by an unresponsive root-owned
CoreSimulator `simdiskimaged` service in the Xcode 27 beta environment; see
`docs/RECOVERY_AND_LECTURE_CHECKLIST.md`. No Lecture source changes will begin
until the environment, existing Draw/Trackpad behavior, and both builds are green.

For free Apple accounts, `scripts/install-personal.sh` produces optimized Release builds, packages the Mac app, and refreshes the physical iPad installation. Its project-local Team/device configuration is ignored by Git. Apple still limits Personal Team provisioning to 7 days, so permanent native iPad distribution remains dependent on paid-program signing.
