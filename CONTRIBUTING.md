# Contributing to DrawPad

Thanks for improving DrawPad. Keep changes focused, native, and verifiable.

## Development workflow

1. Read `AGENTS.md` and the architecture documentation.
2. Create a focused branch from the current main development branch.
3. Add or update a failing test first for deterministic logic when practical.
4. Make the smallest implementation change that satisfies the test.
5. Run:

   ```bash
   ./scripts/build.sh
   ./scripts/test.sh
   ```

6. Document behavior, protocol, permission, or architecture changes.
7. Use a concise imperative commit message such as `fix: reject stale video frames`.

## Design constraints

- Use Swift and native Apple frameworks only.
- Do not add runtime dependencies without prior discussion.
- Keep video and control traffic on separate channels.
- Keep transmitted drawing coordinates normalized with a top-left origin.
- Preserve finger input as a first-class path; Apple Pencil must remain optional.
- Do not add remote input, audio, cloud services, accounts, or telemetry to V1.
- Keep UI state on the main actor and give network/video work explicit ownership.
- Never bypass Apple privacy controls or add unrelated permissions.

## Pull requests

Describe the user-visible result, tests performed, physical-device coverage, and any manual validation still required. Include screenshots for visual changes. Do not claim physical-device behavior was tested when it was only compiled or simulated.

## Project file changes

`project.yml` is the project-structure source of truth. If a source file or build setting changes, run `xcodegen generate` and commit the generated Xcode project alongside it. Never commit a personal Development Team ID, provisioning profile, or `xcuserdata`.
