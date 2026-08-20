# Security Policy

## Project status

Skeldri listens through Bonjour-advertised local-network services and accepts one approved iPad session. Every connection uses a random session identifier to bind its control and video channels. The Mac must explicitly approve each new session before it transmits screen content or accepts drawing, display-selection, or trackpad commands. Pending and unclassified connections are bounded and time out.

This approval is authorization, not cryptographic pairing. Application payloads are not end-to-end encrypted and a hostile local network remains outside the threat model. Use Skeldri only on a trusted LAN. A future release can add an authenticated key exchange without changing drawing or video ownership.

Optional pointer input is separately permission-gated by macOS, explicitly enabled from the iPad, sequence checked, value bounded, and reset whenever its session or mode ends. Skeldri never bypasses Screen Recording or Accessibility consent.

Use Skeldri only on a trusted LAN. Do not expose its listener through port forwarding, a public address, or an untrusted network.

## Reporting a vulnerability

Do not publish exploitable details in a public issue. Contact the repository owner privately through the security-reporting mechanism provided by the hosting repository. Include affected versions, reproduction steps, impact, and any suggested mitigation.

## In scope

- Unexpected non-LAN exposure.
- Memory-safety or denial-of-service issues in packet parsing or video handling.
- Permission or sandbox boundary violations.
- Sensitive data written to logs.
- Unauthorized control-channel actions.

General feature requests and availability problems belong in the normal issue tracker.
