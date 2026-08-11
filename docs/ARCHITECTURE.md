# Architecture

DrawPad has native macOS and iPadOS apps plus shared models and protocol code. The Mac is authoritative for display and connection configuration.

The macOS target is a menu-bar-only application (`LSUIElement`). Its app delegate owns startup so Bonjour discovery and display enumeration begin when the process launches, independently of whether the menu-bar popover is open.

ScreenCaptureKit captures the selected display with DrawPad windows excluded. VideoToolbox encodes low-latency H.264 and sends it over a dedicated TCP channel. The iPad displays samples with `AVSampleBufferDisplayLayer`. A separate control TCP channel carries normalized vector drawing events, keeping input responsive when video is delayed. The Mac publishes and validates display descriptors; the iPad sidebar requests selection by stable display ID, after which the Mac moves the overlay and restarts capture. One main-actor reconciliation loop owns capture start/stop and coalesces rapid display taps with latest-request-wins behavior. The iPad marks a display selected only after the Mac confirms it.

The normal quality profile scales the captured display to a maximum dimension of 1600 pixels, requests 30 FPS, encodes at approximately 4 Mbps with a 5 Mbps data-rate ceiling, disables frame reordering, and emits a keyframe at least once per second. Capture retains two surfaces. The encoder permits one VideoToolbox frame in flight and one replaceable newest raw frame, so overload is discarded before encoding where it cannot break H.264 references.

VideoToolbox AVCC access units are kept length-prefixed end-to-end. SPS/PPS is resent on keyframes, but the iPad flushes only for a new encoder-generation UUID. Each encoded frame has a monotonic sequence number. The Mac permits at most two frames that the iPad has not acknowledged; a rejected frame forces the next encoded frame to be an IDR. The decoder rejects old generations, duplicates, and dependent frames after a sequence gap, then requests keyframe recovery. A saturated or failed display renderer is flushed instead of accumulating stale video. Video acknowledgements stay on the network/encoder path and never trigger main-actor annotation work.

`SCStream` is primary; a first-frame watchdog uses ScreenCaptureKit's screenshot API as a temporary 30 FPS fallback on SDK/OS combinations where a started stream emits no samples, and exits if stream output recovers.

The iPad applies touches locally before transmission. Both peers maintain deterministic `DrawingState`. Coordinates use a top-left origin in `[0, 1]`; `CoordinateMapper` accounts for aspect-fit letterboxing. The Mac overlay is transparent, non-activating, mouse-transparent, and excluded from capture.

Network.framework advertises/browses `_drawpad._tcp` on the LAN. There is no cloud endpoint, telemetry, audio, or keyboard input. The optional trackpad path is isolated behind an explicit iPad mode, validates and sequences every relative event, and uses macOS's permission-gated Quartz posting API. Mode exit, disconnection, navigation Back, and iPad suspension all release held buttons. Screen recording and pointer control remain governed solely by macOS privacy controls.

Each Mac installation persists a stable, non-secret service UUID in `UserDefaults` and advertises it in the Bonjour TXT record. The iPad reconciles browse results by this identity, with a compatibility fallback for Bonjour's numeric auto-rename suffixes. Browser refreshes use generation tokens so callbacks from a cancelled browser cannot restore stale entries. macOS Launch Services is also instructed to prohibit multiple DrawPadMac instances.
