# Wire Protocol

Protocol version is `7`. Every TCP message is framed as a 4-byte unsigned big-endian payload length, a 1-byte packet type, then payload bytes. The length includes the type byte. Receivers accept fragmented/coalesced reads and reject zero lengths or payloads above the channel limit (control: 1 MiB; video: 16 MiB).

Packet types: `1` JSON control packet, `2` video configuration JSON, `3` encoded H.264 access unit. Unknown types are rejected. A video-frame payload starts with a 4-byte big-endian JSON-header length, the `VideoFrameHeader` JSON, then the VideoToolbox AVCC access unit.

Two TCP connections are opened to the same Bonjour service. Each begins with a control `hello` declaring protocol version, `control` or `video` channel, and the same freshly generated session UUID. Incompatible versions and mismatched channel sessions are rejected. The Mac sends `authorizationRequired` and waits for a local Allow/Reject decision. No screen data is transmitted and no peer mutation is accepted before approval. The result is returned as `authorizationResult`; unanswered requests expire after 60 seconds. Control messages also include ping/pong, video acknowledgement/recovery requests, display state, drawing mutations, `inputMode`, and `trackpad` events.

Trackpad events carry a monotonically increasing `UInt64` sequence and one of: relative move, pixel scroll, relative magnification, button transition, or reset. The Mac accepts them only while the peer has explicitly selected Trackpad mode, rejects duplicate/out-of-order sequences and non-finite values, clamps untrusted deltas, and releases all held buttons on reset, mode exit, or disconnect. Magnification is accumulated into standard Command-Plus/Minus application zoom steps because macOS does not expose a supported system-wide API for synthesizing native magnify events. Drawing and trackpad surfaces are mutually exclusive on iPad.

## Lecture (Read) mode

Version `7` adds a third, read-only experience alongside Draw and Trackpad. `inputMode` gains a `lecture` case, and four control messages carry its lifecycle: `requestLectureSourceSelection(requestID:)`, `lectureSourceSelected(_:generation:)`, `lectureSourceUnavailable(reason:generation:)`, and `leaveLectureMode`.

Selection is request-correlated. The iPad mints a fresh `requestID` per request, and the Mac must echo it as the `generation` of its reply. The iPad accepts a reply only when its generation matches the outstanding request or the currently active generation; anything else is dropped. Leaving Read mode invalidates the outstanding request, so a delayed reply can never resume presenting captured content after the user has left. `lectureSourceUnavailable` is correlated the same way and therefore cannot move an idle session into an error state.

`LectureSourceDescriptor` is bounded on decode: a non-empty name of at most 256 UTF-8 bytes and both dimensions within `1...16384`. Source identifiers are meaningful only within the current connection. Read mode is strictly read-only — it never carries drawing, pointer, click, keyboard, or remote scroll events. Zoom and pan are applied locally to decoded pixels and are never sent to the Mac.

Skeldri Afi remains on its own protocol version `1` and gains nothing from this bump. Its adapter rejects `inputMode: lecture` as an invalid payload, rejects the lecture message kinds as unknown, and cannot encode them outbound, so an unsupported selection degrades explicitly instead of corrupting a legacy Draw/Trackpad session.

## Display and video

The Mac validates display-selection requests, moves its overlay, restarts capture, and confirms the selected descriptor. Video configuration supplies a stream-generation UUID, width, height, and base64 SPS/PPS. Every frame supplies that UUID, a monotonic `UInt64` sequence, presentation time, and keyframe flag before its VideoToolbox AVCC access unit. The iPad acknowledges a frame only after accepting it for immediate display. At most two frames may remain unacknowledged. If the iPad detects a gap or renderer failure, its acknowledgement requests a keyframe; the Mac drops dependent output until a forced IDR can resume safely.
