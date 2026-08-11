# DrawPad Engineering Rules

- Work only in this repository. Keep DerivedData and temporary artifacts in `.build/`.
- Use native Swift and Apple frameworks only; no third-party runtime dependencies.
- Compile after meaningful changes and address compiler warnings/errors deliberately.
- Maintain `docs/ARCHITECTURE.md`, `docs/PROTOCOL.md`, and `docs/IMPLEMENTATION_STATUS.md`.
- Follow SOLID and the dependency rules in `docs/CLEAN_ARCHITECTURE.md`; document public APIs and architectural reasoning.
- Remote input is limited to the explicitly selected iPad trackpad mode and macOS pointer permission; do not add keyboard control, audio, cloud backend, accounts, telemetry, or Internet service.
- Finger drawing is mandatory and must not require Apple Pencil.
- Drawing data uses normalized, top-left-origin screen coordinates.
- Networking is local-only through Bonjour and Network.framework.
- Never modify machine-wide configuration, privacy settings, or files outside this repository.
