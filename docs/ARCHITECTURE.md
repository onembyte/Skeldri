# Architecture

DrawPad has native macOS and iPadOS apps plus shared models and protocol code. The Mac is authoritative for display and connection configuration.

ScreenCaptureKit captures the selected display with DrawPad windows excluded. VideoToolbox encodes low-latency H.264 and sends it over a dedicated TCP channel. The iPad displays samples with `AVSampleBufferDisplayLayer`. A separate control TCP channel carries normalized vector drawing events, keeping input responsive when video is delayed. The Mac publishes and validates display descriptors; the iPad sidebar requests selection by stable display ID, after which the Mac moves the overlay and restarts capture.

The normal quality profile scales the captured display to a maximum dimension of 1600 pixels, requests 30 FPS, encodes at approximately 4 Mbps, disables frame reordering, and emits a keyframe at least every 60 frames. VideoToolbox AVCC access units are kept length-prefixed end-to-end. SPS/PPS is resent on keyframes so a reconnecting decoder can recover without stale format state. Video transport permits only one in-flight frame and one replaceable pending frame, preventing obsolete frames from accumulating behind real time. `SCStream` is primary; a first-frame watchdog uses ScreenCaptureKit's screenshot API as a temporary 30 FPS fallback on SDK/OS combinations where a started stream emits no samples, and exits if stream output recovers.

The iPad applies touches locally before transmission. Both peers maintain deterministic `DrawingState`. Coordinates use a top-left origin in `[0, 1]`; `CoordinateMapper` accounts for aspect-fit letterboxing. The Mac overlay is transparent, non-activating, mouse-transparent, and excluded from capture.

Network.framework advertises/browses `_drawpad._tcp` on the LAN. There is no cloud endpoint, telemetry, audio, Accessibility access, or remote input. The apps use outgoing/incoming network sandbox entitlements as needed. Screen recording is governed solely by macOS privacy controls.
