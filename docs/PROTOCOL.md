# Wire Protocol

Protocol version is `1`. Every TCP message is framed as a 4-byte unsigned big-endian payload length, a 1-byte packet type, then payload bytes. The length includes the type byte. Receivers accept fragmented/coalesced reads and reject zero lengths or payloads above the channel limit (control: 1 MiB; video: 16 MiB).

Packet types: `1` JSON control packet, `2` video configuration JSON, `3` encoded H.264 access unit. Unknown types are rejected.

Two TCP connections are opened to the same Bonjour service. Each begins with a control `hello` declaring protocol version and `control` or `video` channel. Incompatible versions are rejected. Control messages include hello, ping/pong, display metadata, stroke begin/points/end, explicit stroke deletion, clear, and canvas snapshot. Video configuration supplies width, height, and base64 SPS/PPS; frame metadata prefixes Annex-B encoded access units.

