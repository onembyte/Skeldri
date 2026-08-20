# Security Audit

Audit date: August 12, 2026

## Controls implemented

- App Sandbox and Hardened Runtime are enabled for the Mac target, with only client/server network sandbox exceptions.
- Screen capture and pointer control remain behind macOS consent; no privacy setting is modified programmatically.
- A random session UUID binds the two TCP channels, and every new session requires an explicit Mac-side Allow decision.
- Video and control mutations are blocked before approval. Rejected, timed-out, malformed, oversized, duplicate, and additional-client traffic is rejected.
- Packet sizes, pointer values, event ordering, display identifiers, frame generations, and decode inputs are validated.
- Only local Bonjour services are browsed or advertised. There is no cloud endpoint, telemetry, account system, microphone, camera, or audio capture.
- Privacy manifests declare no tracking or data collection and document the UserDefaults required-reason API.
- Logs avoid individual touch coordinates and screen contents.
- Shutdown cancels capture, encoding, listeners, connections, overlays, and pointer state.

## Residual risks

- TCP payloads are not end-to-end encrypted or cryptographically authenticated. Mac approval prevents accidental or drive-by use but does not defeat an active attacker on a hostile LAN.
- Bonjour is not guaranteed to cross guest-network isolation, VLANs, or restrictive enterprise Wi-Fi.
- Accessibility and Screen Recording grants must be re-approved when bundle identity or signing identity changes. The Accessibility path is limited to validated pointer/button/scroll events and the standard Command-plus/Command-minus magnification shortcut; arbitrary keyboard text is never accepted by the protocol.
- The compatibility listener deliberately supports one old iPad client. It is isolated by service type and codec, but carries the same trusted-LAN limitation.

## Release gate

Before submission, physically validate the signed sandboxed Mac build with both iPad clients, including Allow, Reject, timeout, disconnect, and pointer reset. Host the privacy policy over HTTPS and complete App Store Connect privacy answers as “Data Not Collected.”
