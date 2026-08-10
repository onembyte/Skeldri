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
| 9 — iPad video decoder | Implemented and installed; final visual confirmation remains |
| 10 — Composite video + annotation | Implemented and compiled; alignment validation pending |
| 11 — Toolbar | Implemented and installed, including direct clear and active-tool indicators |
| 12–13 | Pending/in progress |

A USB iPad (7th generation, iPadOS 18.6.2) is connected and trusted. Signed builds install and launch successfully. Bonjour discovery, connection, drawing synchronization, and destructive drawing actions have been exercised. The latest matched Mac/iPad build adds iPad-side display selection; final visual confirmation of decoded video and display switching remains.
