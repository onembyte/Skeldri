# Recovery and Lecture Viewport Checklist

This checklist is the execution gate after the interrupted model switch on
2026-08-12. Existing behavior is stabilized and revalidated before Lecture
mode changes the protocol, capture lifecycle, or iPad presentation.

## Verified recovery state

- [x] Modern repository is clean and matches `origin/agent/personal-install`.
- [x] Legacy repository is clean and matches `origin/agent/app-store-security`.
- [x] No incomplete Lecture-mode source files or mixed working-tree changes exist.
- [x] Modern automated baseline passes: 40 tests in 13 suites.
- [x] The current failure is outside Swift compilation: Xcode 27 beta loses
  `CoreSimulatorService` because the root-owned `simdiskimaged` service is
  unresponsive, and `xcodebuild` exits with signal 15 before compiling.
- [x] A non-privileged restart was attempted and correctly refused; Skeldri did
  not use `sudo` or change machine-wide configuration.
- [x] The separate Xcode 9.4.1 extraction for Skeldri Afi is still running on
  the TrueNAS-backed volume. It is unrelated to the modern feature branch and
  must not be mixed into Lecture work.

## Gate A — restore a trustworthy build environment

Completed 2026-08-12. The blocker was the system service, not the repository.

- [ ] Allow the current Xcode 9 extraction to finish or stop it deliberately.
  Still expanding (`xip --expand Xcode_9.4.1.xip`) onto the TrueNAS-backed
  volume. It is unrelated to this branch and does not gate the modern build.
- [x] Restart the Mac so the root-owned CoreSimulator disk-image service starts
  cleanly. No repo change can repair that system service.
- [x] Run `./scripts/doctor.sh` and confirm the simulator-service preflight is
  healthy. Reports `Healthy`; the physical iPad (7th generation, iPadOS 18.6.2)
  is listed as available.
- [x] Run `xcodebuild -list -project Skeldri.xcodeproj` successfully.
- [x] Run `./scripts/test.sh`; retain the 40-test baseline. Now 48 tests in 14
  suites, all passing.
- [x] Run `./scripts/build.sh`; confirm both SkeldriMac and generic SkeldriPad
  simulator builds succeed. This required fixing a Swift 6 strict-concurrency
  error in the Lecture rail's `deinit`, which was also unreachable.
- [x] Do not begin Lecture implementation until every Gate A item is green.

## Gate B — regression sweep of existing behavior

- [ ] Install matching current Mac and iPad builds together.
- [ ] Connect once, reject once, reconnect, and disconnect with Back.
- [ ] Confirm mirroring remains low latency and never returns to a stale stream
  after a display switch.
- [ ] Confirm Draw, Pen, Highlighter, Eraser, Undo, Clear, and clear-on-switch.
- [ ] Confirm Trackpad move, click, double/triple click, drag, scroll, and pinch
  classification; pinch must not emit scroll for the same gesture.
- [ ] Confirm leaving Trackpad releases every pressed mouse button.
- [ ] Record any reproducible app defect as a failing test before its fix.

## Gate C — Lecture domain, navigation, and protocol (TDD)

Complete 2026-08-12.

- [x] Add `lecture` as a third mutually exclusive experience mode.
- [x] Test transitions among Draw, Trackpad, and Lecture, including trackpad
  reset when Trackpad loses ownership.
- [x] Define and test Lecture session states: inactive, selecting, active,
  source unavailable, disconnected, and leaving. Selection is request-correlated,
  so a reply to an abandoned request cannot resume presenting captured content.
- [x] Implement the pure navigation-rail policy first; test dead zone, cubic
  acceleration, precision gain, clamping, elapsed-time integration, and
  accessibility increments.
- [x] Define bounded source descriptors and selection messages.
- [x] Extend Codable round-trip and malformed-input coverage.
- [x] Bump the modern protocol version deliberately and document compatibility.
- [x] Keep Skeldri Afi protocol 1 unchanged; unsupported Lecture selection must
  degrade explicitly rather than corrupting its Draw/Trackpad session.

## Gate D — three-state mode control

- [x] Replace the two-state top-right button with a compact native SwiftUI
  Draw / Trackpad / Read selector.
- [x] Use SF Symbols, semantic materials, native Liquid Glass on iPadOS 26+,
  and the existing material fallback on iPadOS 18.
- [x] Give each segment a minimum 44-point target, selected-state contrast,
  VoiceOver label/value, Reduce Motion behavior, and keyboard focus semantics.
  The segments were 40 points and were corrected to 44; the selector itself is
  unanimated, so Reduce Motion has nothing to suppress.
- [x] Keep Back at top left and ensure the selector consumes touches without
  leaking them into drawing, trackpad, or viewport gestures.
- [ ] Snapshot/manual-check portrait, landscape, light/dark appearance, and
  large accessibility text without introducing bitmap UI assets. Owner action —
  needs a device or simulator visual pass.

## Gate E — Lecture capture and viewport

Code-complete 2026-08-12; none of it exercised on hardware yet.

- [x] Add a Mac capture-source boundary that supports the current display and a
  user-approved ScreenCaptureKit window source.
- [x] Exclude Skeldri-owned windows and reject stale/unavailable source IDs.
  Handles are retained only for windows that passed the eligibility rules, so an
  excluded window cannot be started later.
- [x] Serialize display/window capture changes through the existing
  reconciliation owner; never run overlapping `SCStream` lifecycles.
- [x] Attach a generation UUID to each accepted source and reject delayed frames
  from prior sources.
- [x] Build the iPad viewport around the decoded surface with immediate local
  pinch zoom, pan, fit/reset, and a collapsed precision navigation rail.
- [x] Keep Lecture read-only: no drawing packets, mouse events, clicks, keyboard
  events, or generic remote scroll events. Enforced by the Mac, not only hidden
  by the iPad.
- [x] Show explicit states for selecting, window closed/unavailable, connection
  lost with last frame retained, and permission required. An owner declining the
  picker reports its own reason rather than a fabricated failure.
- [x] Restore the previously selected display stream when leaving Lecture.

## Gate F — quality, security, and release validation

- [ ] Measure text legibility, viewport frame pacing, decode memory, bitrate,
  end-to-end delay, thermal behavior, and reconnect recovery on the modern iPad.
- [ ] Confirm the Mac remains usable in a different foreground app while the
  approved Lecture window continues updating.
- [ ] Verify minimized/hidden/other-Space behavior empirically and document the
  observed OS limitations.
- [ ] Repeat all existing Draw and Trackpad acceptance checks.
- [x] Run unit tests, Mac build, simulator build, signed Mac build, and physical
  iPad install/launch. Unit tests (58 in 16 suites), Mac build, and generic
  simulator build pass; `release-audit.sh` produces both unsigned App Store-shaped
  archives. Signed install and launch on the physical iPad remain owner actions.
- [x] Review App Sandbox, privacy manifest, Screen Recording explanation,
  local-network disclosure, and App Review notes. Add no private virtual-display
  API and make no true-extended-display claim. Read mode uses only public
  ScreenCaptureKit window/display capture and is documented as a reading viewport
  over captured pixels, never an extended display.
- [x] Update architecture, protocol, manual testing, troubleshooting, status,
  and README documents.
- [x] Commit each green TDD milestone separately and push only reviewed, clean
  commits to the existing private branch/PR. Milestones are committed separately
  and remain unpushed pending owner review.

## Product boundary

Lecture is a selected-window or selected-display reading viewport. Local zoom
and pan move through captured pixels and remain responsive without a network
round trip. It is not a macOS virtual monitor and cannot reveal off-screen pages
of an arbitrary document without mutating the Mac application. A later native
PDF/image reader is the correct path for truly independent long-document scroll.
