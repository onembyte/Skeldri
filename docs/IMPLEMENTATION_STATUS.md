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

A USB iPad (7th generation, iPadOS 18.6.2) was used for validation. Signed builds install and launch successfully. Bonjour discovery, connection, video mirroring, drawing synchronization, destructive drawing actions, and repeated display switching have been exercised. Display switching serializes capture lifecycle operations, coalesces rapid requests, confirms selection from the Mac, and rejects video frames from obsolete encoder generations. Protocol 5 retains bounded video recovery and adds sequenced, validated trackpad movement, scroll, click, drag, and accumulated pinch-zoom events with mode-exit, background, Back-navigation, and disconnect release semantics. Physical pinch behavior across representative Mac applications remains a manual acceptance item.

For free Apple accounts, `scripts/install-personal.sh` produces optimized Release builds, packages the Mac app, and refreshes the physical iPad installation. Its project-local Team/device configuration is ignored by Git. Apple still limits Personal Team provisioning to 7 days, so permanent native iPad distribution remains dependent on paid-program signing.
