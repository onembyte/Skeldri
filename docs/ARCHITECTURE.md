# Architecture

DrawPad has native macOS and iPadOS apps plus shared models and protocol code. The Mac is authoritative for display and connection configuration.

ScreenCaptureKit captures the selected display with DrawPad windows excluded. VideoToolbox encodes low-latency H.264 and sends it over a dedicated TCP channel. The iPad displays samples with `AVSampleBufferDisplayLayer`. A separate control TCP channel carries normalized vector drawing events, keeping input responsive when video is delayed.

The iPad applies touches locally before transmission. Both peers maintain deterministic `DrawingState`. Coordinates use a top-left origin in `[0, 1]`; `CoordinateMapper` accounts for aspect-fit letterboxing. The Mac overlay is transparent, non-activating, mouse-transparent, and excluded from capture.

Network.framework advertises/browses `_drawpad._tcp` on the LAN. There is no cloud endpoint, telemetry, audio, Accessibility access, or remote input. The apps use outgoing/incoming network sandbox entitlements as needed. Screen recording is governed solely by macOS privacy controls.

