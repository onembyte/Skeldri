# Changelog

All notable project changes will be documented here. DrawPad has not published a stable release yet.

## Unreleased

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

- Personal installation now restarts DrawPadMac after upgrades so the Mac and iPad cannot retain mismatched in-memory protocol versions.
- End-to-end video acknowledgements cap TCP at two unconsumed frames.
- Capture and encoding queues discard overload before H.264 compression, then force IDR recovery after congestion.
- Sequence-aware decoding rejects broken reference chains, stale generations, and duplicate frames.
- Repeated SPS/PPS no longer flushes the iPad display layer; renderer pressure flushes stale video instead of buffering it.
- Encoder-generation identifiers prevent frames from a previous display entering a new decode session.
- Display switching is serialized and uses latest-request-wins reconciliation.
- Bonjour discovery deduplicates Mac instances by stable identity and guards refreshes against stale browser callbacks.
