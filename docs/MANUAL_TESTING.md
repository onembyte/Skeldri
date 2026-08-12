# Manual Acceptance Testing

## Connection

- [ ] Mac app launches and advertises over Bonjour
- [ ] iPad discovers, connects, and shows connected state

## Screen

- [ ] Selected Mac display appears with correct aspect ratio and cursor
- [ ] Image is readable
- [ ] Mac control and annotation windows are not recursively captured

## Drawing and tools

- [ ] Finger stroke appears immediately on iPad and aligns on Mac; no Pencil required
- [ ] Pen, highlighter, color, thickness, stroke eraser, undo, and clear work
- [ ] Hide/show restores Mac annotations
- [ ] Two-finger pinch magnifies the Draw surface; one finger still draws
- [ ] Strokes drawn while magnified land in the same place on the Mac as unmagnified ones
- [ ] Starting a pinch withdraws the mark the first finger began instead of leaving a scratch
- [ ] Two-finger pan only moves within content that exists, never past the edge
- [ ] Two-finger double-tap returns to the unzoomed surface
- [ ] Pinching back out snaps cleanly to 1x and re-centres
- [ ] Switching display or experience mode resets the magnification

## Trackpad and navigation

- [ ] Top-right control switches between Draw and Trackpad without leaking gestures between surfaces
- [ ] One-finger movement, tap, hold-and-drag, natural two-finger vertical/horizontal scroll, pinch zoom, and two-finger secondary click work
- [ ] Double-tap selects a word and triple-tap selects the containing paragraph/line in standard Mac text fields
- [ ] Very slow two-finger scrolling remains responsive without lost fractional movement
- [ ] Left settings button unfolds and collapses without generating pointer input underneath
- [ ] Sensitivity and speed sliders update pointer response immediately
- [ ] Acceleration toggle preserves precise slow motion and increases travel for fast gestures
- [ ] Trackpad settings persist after closing and reopening the iPad app
- [ ] Leaving Trackpad mode, backgrounding iPad, disconnecting, and tapping Back release any held button
- [ ] Top-left Back returns to Mac discovery and the same Mac can reconnect

## Read (Lecture) mode

- [ ] Selecting Read on the iPad raises a reading request in the Mac menu-bar popover
- [ ] The picker lists displays and ordinary windows, and never lists Skeldri's own windows
- [ ] Approving a window streams that window; the Mac stays usable in a different foreground app
- [ ] "Don't share" returns the iPad to an explicit declined message, not a fabricated failure
- [ ] Pinch zoom, pan, double-tap zoom, and fit/reset respond locally without a network round trip
- [ ] The navigation rail scrolls with acceleration, slows for precision away from the rail, and honours VoiceOver increment/decrement
- [ ] No drawing or pointer input reaches the Mac while Read is active
- [ ] Closing the captured window reports "window was closed" rather than freezing on the last frame silently
- [ ] Leaving Read restores the previously selected display stream and its aspect ratio
- [ ] Disconnecting during Read retains the last frame and reports connection lost
- [ ] Denying or revoking Screen Recording reports "permission required"
- [ ] Verify minimized, hidden, and other-Space behavior empirically and record the observed OS limitations

## Mac usability and stability

- [ ] Overlay passes mouse clicks and does not steal keyboard focus
- [ ] Either peer can disconnect/reconnect without a crash
- [ ] Rotation preserves coordinates
- [ ] Both apps shut down cleanly
