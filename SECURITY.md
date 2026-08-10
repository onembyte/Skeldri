# Security Policy

## Project status

DrawPad is a local-development MVP, not a hardened remote-desktop product. It listens only through its Bonjour-advertised local-network service and accepts one iPad session. Protocol version compatibility is checked, but V1 does not authenticate or encrypt peers at the application layer.

Use DrawPad only on a trusted LAN. Do not expose its listener through port forwarding, a public address, or an untrusted network.

## Reporting a vulnerability

Do not publish exploitable details in a public issue. Contact the repository owner privately through the security-reporting mechanism provided by the hosting repository. Include affected versions, reproduction steps, impact, and any suggested mitigation.

## In scope

- Unexpected non-LAN exposure.
- Memory-safety or denial-of-service issues in packet parsing or video handling.
- Permission or sandbox boundary violations.
- Sensitive data written to logs.
- Unauthorized control-channel actions.

General feature requests and availability problems belong in the normal issue tracker.
