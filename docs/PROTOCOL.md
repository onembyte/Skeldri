# Wire Protocol

Protocol version is `1`. Every TCP message is framed as a 4-byte unsigned big-endian payload length, a 1-byte packet type, then payload bytes. The length includes the type byte. Receivers accept fragmented/coalesced reads and reject zero lengths or payloads above the channel limit (control: 1 MiB; video: 16 MiB).

Packet types: `1` JSON control packet, `2` video configuration JSON, `3` encoded H.264 access unit. Unknown types are rejected. A video-frame payload starts with a 4-byte big-endian JSON-header length, the `VideoFrameHeader` JSON, then the VideoToolbox AVCC access unit.

Two TCP connections are opened to the same Bonjour service. Each begins with a control `hello` declaring protocol version and `control` or `video` channel. Incompatible versions are rejected. Control messages include hello, ping/pong, the available-display list, selected-display metadata, an iPad display-selection request, stroke begin/points/end, explicit stroke deletion, clear, and canvas snapshot. The Mac validates display-selection requests, moves its overlay, restarts capture, and confirms the selected descriptor. Video configuration supplies width, height, and base64 SPS/PPS; frame metadata prefixes VideoToolbox AVCC access units.
