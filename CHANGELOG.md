# Changelog

All notable project changes will be documented here. Skeldri has not published a stable release yet.

## Unreleased

- A peer that vanishes without closing its socket, such as an iPad powered off mid-session, is now detected by TCP keepalive instead of being held as a live authorized connection indefinitely.
- Fixed a reconnection failure where the Mac showed a stale session as connected and never raised the approval prompt, leaving the iPad waiting for an approval it could not be given.

- Added three configurable quick colour swatches to the drawing toolbar. Each is a one-tap choice, the existing colour picker reconfigures whichever swatch is selected, and the palette persists locally. The toolbar was widened to carry them.

- Added a fit-to-screen button beside the drawing toolbar that appears only while the Draw surface is magnified.
- Added local two-finger pinch zoom and pan to Draw mode so a finger can write larger on screen than the stroke it produces. Magnification is presentation only: strokes stay in normalized coordinates and land on the Mac exactly where an unzoomed stroke would.

- Added Read (Lecture) mode: a third, read-only experience that mirrors a Mac-approved window or display as a locally zoomable and pannable reading viewport, with a precision navigation rail. It is not a virtual display and adds no private virtual-display API.
- The Mac owner chooses what may be read from a menu-bar picker. The iPad sends only a request identifier and can never name a source; Skeldri's own windows are never offered.
- Read mode is enforced read-only by the Mac, not only hidden on the iPad: drawing mutations and pointer events are refused while the peer declares Read, with the trackpad release fail-safe still allowed.
- Capture lifecycle generalized from a display identifier to a display-or-window capture target under the existing single serial owner, so display and Read streams can never overlap and leaving Read restores the previous display stream.
- Bumped the modern protocol to version 7 for the Read message set. Skeldri Afi stays on its own version 1 and degrades explicitly rather than corrupting a legacy session.
- Added the isolated `_skeldri-afi._tcp` compatibility listener for native iOS 10 clients without changing the modern protocol.
- Hardened two-finger gesture arbitration so pinch zoom and scrolling remain mutually exclusive for the full gesture.
- Replaced the initial rune artwork with Skeldri's flowing Ansuz–Kenaz ribbon identity across both app icons and the Mac menu bar.
- Restyled the iPad Mac-selection screen with the same midnight, cyan-ribbon, and glass-card visual language.
- Added two-finger pinch zoom in Trackpad mode using accumulated standard macOS application zoom shortcuts.
- Added the shared Ansuz–Kenaz rune app icon to the macOS and iPadOS targets, plus an adaptive monochrome menu-bar mark.
- Renamed the product, Xcode project, targets, schemes, Bonjour service, source types, scripts, and documentation from DrawPad to Skeldri.
- Added an explicit iPad Draw/Trackpad toggle with relative movement, clicking, dragging, two-finger scrolling, and secondary click.
- Trackpad mode now uses a distraction-free gray surface and hides video, display selection, and drawing tools.
- Added a collapsible left-side trackpad settings control for sensitivity, speed, and optional pointer acceleration; preferences persist locally.
- Added lossless natural two-finger scrolling and native double/triple-tap click states for word and paragraph selection.
- Added a top-left Back control that returns to discovery and safely resets pointer state.
- Added permission-gated Mac pointer injection, protocol replay protection, bounded event validation, and disconnect/background fail-safes.

### Added

- Retro monospaced empty state for iPad connection discovery.
- Menu-bar-only Mac presentation with status and annotation controls in a compact popover.
- Native macOS and iPadOS targets with shared domain and protocol code.
- ScreenCaptureKit capture and low-latency VideoToolbox H.264 transport.
- Bonjour discovery with separate TCP video and control channels.
- Finger-first vector annotations synchronized with a transparent Mac overlay.
- Pen, highlighter, stroke eraser, color, thickness, undo, clear, and overlay visibility controls.
- iPad display selection with optional clear-on-switch behavior.
- Native Liquid Glass floating controls with backward-compatible material styling.
- Unit coverage for framing, protocol coding, coordinates, drawing state, and hit testing.
- One-command Personal Team Release builds, Mac packaging, and physical-iPad installation/refresh.

### Reliability

- Personal installation now restarts SkeldriMac after upgrades so the Mac and iPad cannot retain mismatched in-memory protocol versions.
- End-to-end video acknowledgements cap TCP at two unconsumed frames.
- Capture and encoding queues discard overload before H.264 compression, then force IDR recovery after congestion.
- Sequence-aware decoding rejects broken reference chains, stale generations, and duplicate frames.
- Repeated SPS/PPS no longer flushes the iPad display layer; renderer pressure flushes stale video instead of buffering it.
- Encoder-generation identifiers prevent frames from a previous display entering a new decode session.
- Display switching is serialized and uses latest-request-wins reconciliation.
- Bonjour discovery deduplicates Mac instances by stable identity and guards refreshes against stale browser callbacks.
