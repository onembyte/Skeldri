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
- [ ] One-finger movement, tap, double-tap, hold-and-drag, two-finger scroll, and two-finger secondary click work
- [ ] Leaving Trackpad mode, backgrounding iPad, disconnecting, and tapping Back release any held button
- [ ] Top-left Back returns to Mac discovery and the same Mac can reconnect

## Mac usability and stability

- [ ] Overlay passes mouse clicks and does not steal keyboard focus
- [ ] Either peer can disconnect/reconnect without a crash
- [ ] Rotation preserves coordinates
- [ ] Both apps shut down cleanly
