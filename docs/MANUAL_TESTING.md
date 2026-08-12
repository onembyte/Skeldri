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

## Trackpad and navigation

- [ ] Top-right control switches between Draw and Trackpad without leaking gestures between surfaces
- [ ] One-finger movement, tap, hold-and-drag, natural two-finger vertical/horizontal scroll, and two-finger secondary click work
- [ ] Double-tap selects a word and triple-tap selects the containing paragraph/line in standard Mac text fields
- [ ] Very slow two-finger scrolling remains responsive without lost fractional movement
- [ ] Left settings button unfolds and collapses without generating pointer input underneath
- [ ] Sensitivity and speed sliders update pointer response immediately
- [ ] Acceleration toggle preserves precise slow motion and increases travel for fast gestures
- [ ] Trackpad settings persist after closing and reopening the iPad app
- [ ] Leaving Trackpad mode, backgrounding iPad, disconnecting, and tapping Back release any held button
- [ ] Top-left Back returns to Mac discovery and the same Mac can reconnect

## Mac usability and stability

- [ ] Overlay passes mouse clicks and does not steal keyboard focus
- [ ] Either peer can disconnect/reconnect without a crash
- [ ] Rotation preserves coordinates
- [ ] Both apps shut down cleanly
