# Changelog

All notable project changes will be documented here. DrawPad has not published a stable release yet.

## Unreleased

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

- End-to-end video acknowledgements cap TCP at two unconsumed frames.
- Capture and encoding queues discard overload before H.264 compression, then force IDR recovery after congestion.
- Sequence-aware decoding rejects broken reference chains, stale generations, and duplicate frames.
- Repeated SPS/PPS no longer flushes the iPad display layer; renderer pressure flushes stale video instead of buffering it.
- Encoder-generation identifiers prevent frames from a previous display entering a new decode session.
- Display switching is serialized and uses latest-request-wins reconciliation.
- Bonjour discovery deduplicates Mac instances by stable identity and guards refreshes against stale browser callbacks.
