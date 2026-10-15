# Lecture Mode Feasibility and Implementation Plan

Status: design only; no Lecture-mode functionality has been implemented.

## Product definition

Lecture mode is a read-focused iPad workspace. It locks to one user-approved Mac window or display, removes drawing and trackpad controls, and provides local, fluid pan and zoom plus a precision vertical navigation rail.

The recommended first release is a **secondary reading viewport**, not a macOS virtual display. The user selects a Mac window with Apple's ScreenCaptureKit sharing picker, then may cover that window and continue working in another Mac app while the selected window remains streamed to the iPad. This satisfies the useful single-monitor workflow without private APIs or a display driver.

## Feasibility boundary

| Approach | Independent Mac desktop | App Store-safe | Text quality | Recommendation |
|---|---:|---:|---:|---|
| Selected-window Lecture viewport | Partial: selected window can remain behind other work | Yes | High with Retina capture | Build first |
| Display capture with local pan/zoom | No | Yes | High only until source pixels are exhausted | Useful fallback |
| Native PDF/image reader on iPad | Yes for documents, not arbitrary apps | Yes | Excellent | Potential later feature |
| Software-created macOS virtual display | Yes | No supported public implementation identified | Potentially excellent | Do not put in App Store bundle |

ScreenCaptureKit captures existing displays, applications, and windows; it does not create a display that macOS can arrange in Displays settings. The commonly used virtual-display interfaces are private and therefore unsuitable for App Store submission. DriverKit documents hardware-oriented driver families but no public virtual-display family that solves this product requirement.

## Important semantic distinction

Local pan moves around pixels already captured from the chosen source. It does not scroll a long document inside Safari, Preview, Word, or another Mac app. Sending scroll events to that app would mutate the Mac session and would no longer be strictly read-only. Generic, exact-window background scrolling is not reliably available across arbitrary Mac applications.

Therefore V1 should promise:

- lock to and continuously view one selected window;
- cover that source window on the Mac and continue using another app;
- locally zoom and pan the current window content;
- preserve the last good frame during brief source updates;
- never send pointer, click, keyboard, or document-scroll events in Lecture mode.

If independent long-document scrolling is essential, the robust solution is a later native document path: explicitly transfer a user-selected PDF/image to the iPad and render it with PDFKit/Core Graphics. That is genuinely independent and gives better typography than video, but it is not arbitrary Mac-window streaming.

## Recommended user experience

1. The top-right mode control offers Draw, Trackpad, and Lecture.
2. Entering Lecture asks the Mac to present Apple's content-sharing picker.
3. The Mac user selects one window or display and approves the session.
4. The iPad shows a clean full-screen reading surface with Back, source lock, fit/reset, and a collapsed navigation-rail button.
5. Pinch zoom and two-finger pan happen entirely on the iPad at display refresh rate.
6. Lock prevents accidental source changes. Leaving Lecture or disconnecting releases the source.
7. Drawing, annotation, display selection, and trackpad controls are absent while Lecture is active.

Source loss states must be explicit: **Window closed**, **Source minimized or unavailable**, **Permission required**, and **Connection lost — showing last frame**.

## Visual navigation rail

The rail should support both speed and reading precision without a conventional large scrollbar:

- Dragging its thumb maps directly to normalized vertical viewport position for predictable top-to-bottom jumps.
- Holding above or below the thumb starts velocity navigation.
- Velocity uses a cubic response with a center dead zone: small displacement produces extremely slow movement; large displacement reaches the opposite end in approximately 2–3 seconds.
- Moving the finger horizontally away from the rail reduces the gain for precision scrubbing, following familiar accelerated-scrubber behavior.
- `CADisplayLink` integrates movement by elapsed time, so motion is independent of frame rate.
- Light haptics mark top, bottom, page-sized intervals, and return to the dead zone.

The pure motion function, clamping, dead zone, cubic acceleration, time integration, and accessibility increments must be unit tested before UIKit integration.

## Quality and latency architecture

### Immediate motion

Place the `AVSampleBufferDisplayLayer` surface inside a dedicated UIKit zoom container. Pinch and pan transform the existing decoded surface locally, avoiding a network round trip. The target is native iPad refresh-rate interaction even when video arrives at 30 fps.

### Capture profiles

- Overview: longest dimension 2,560 px, 30 fps, approximately 8–12 Mbps H.264.
- Text detail: capture the selected window at Retina scale, bounded by device decode and memory limits.
- Queue depth remains 2 and frame acknowledgement remains bounded to prevent stale-frame buildup.
- No audio and no recording.

The exact profile must be chosen by measured device capability, thermal behavior, packet loss, and text-legibility tests—not by always sending 4K.

### Detail refinement

During a gesture, scale the current frame locally. After the gesture settles, send a debounced viewport/detail request. For display sources, the Mac can update `SCStreamConfiguration.sourceRect`, width, and height and then force a new keyframe, sharpening only the visible region. ScreenCaptureKit ignores `sourceRect` for a single-window filter, so window sources instead use full-window Retina capture with a safe output cap.

Every detail response needs a generation UUID and viewport revision so stale configurations and frames cannot replace the current locked view.

## Clean Architecture additions

```text
Shared/Domain/Lecture/
  LectureSource.swift
  LectureViewport.swift
  LectureNavigationPolicy.swift
  LectureSessionState.swift

Shared/Application/Lecture/
  EnterLectureMode.swift
  LockLectureSource.swift
  UpdateLectureViewport.swift

macOS/Infrastructure/Capture/
  LectureCaptureController.swift
  ScreenCaptureSourcePicker.swift

iPadOS/Presentation/Lecture/
  LectureScreen.swift
  LectureViewportView.swift
  LectureNavigationRail.swift
```

Capture selection, protocol transport, navigation math, and UIKit rendering remain behind protocols. The existing encoder, decoder, frame acknowledgement, session authorization, and Bonjour channels can be reused.

## Protocol additions

Introduce these only after domain tests:

- `setExperienceMode(draw | trackpad | lecture)`
- `requestLectureSourceSelection`
- `lectureSourceSelected(descriptor, generation)`
- `lectureViewportRequest(rect, outputPixels, revision)`
- `lectureViewportAccepted(rect, revision, streamGeneration)`
- `lectureSourceUnavailable(reason)`
- `leaveLectureMode`

All are control-channel messages, bounded and accepted only for the currently approved session. The Mac remains authoritative for source identity, capture permission, dimensions, and safe output limits.

## TDD milestones

1. Define Lecture state transitions and tests: enter, awaiting source, active, locked, source lost, reconnect, leave.
2. Implement and test navigation-rail acceleration, precision gain, clamping, and accessibility increments.
3. Extend protocol Codable and malformed/bounds tests; bump protocol version deliberately.
4. Add Mac content-sharing picker and selected-window capture behind a feature flag.
5. Prove empirically whether selected windows continue updating when covered, moved to another Space, hidden, and minimized; document each behavior instead of assuming it.
6. Add the iPad UIKit zoom surface and test local gestures with a static high-resolution fixture before networking.
7. Add overview streaming, source locking, last-frame behavior, and disconnect recovery.
8. Add debounced display-region detail refinement with generation/revision tests.
9. Measure text quality, gesture frame pacing, end-to-end latency, memory, bitrate, energy, and thermal behavior on the modern iPad.
10. Run security, privacy, sandbox, App Review, and physical resilience gates before enabling the feature by default.

## Acceptance targets

- Pinch and pan feel immediate and remain near the iPad refresh rate.
- No multi-second video queue develops.
- Normal body text is readable at fit width on the reference iPad.
- The user can traverse the vertical viewport in under 3 seconds and make sub-line-sized precision adjustments.
- Lecture mode emits no drawing, pointer, click, keyboard, or generic scroll commands.
- The Mac remains usable in a different foreground app while an eligible selected window streams.
- Closing or losing the source never crashes either app and never silently switches to another window.

## Decision gate before implementation

Choose whether the first release is:

1. **Lecture Viewport** — arbitrary selected Mac window, live and App Store-safe, with local zoom/pan but no independent long-document scrolling; or
2. **Document Reader** — PDF/image only, genuinely independent, pixel-perfect zoom and long-document scrolling.

Attempting to call the current App Store product a true extended display would be technically inaccurate. A real virtual monitor should be treated as a separate, future distribution investigation rather than silently implemented with private APIs.
