# Suggested App Review Notes

Skeldri is a paired Mac/iPad utility for devices owned and controlled by the same user on one local network. The iPad discovers the Mac using Bonjour. Every connection requires the user to select **Allow** in the Skeldri Mac menu before any screen image or input is exchanged.

The Mac streams one user-selected display to the iPad. The iPad sends normalized annotation strokes that appear in a transparent, click-through overlay. Optional Trackpad mode is clearly selected on the iPad and requires the user to grant macOS Accessibility consent. It sends pointer, button, scroll, and magnification gestures; magnification emits only the focused app's standard Command-plus/Command-minus shortcut. It does not transmit arbitrary keyboard text or key events, and does not provide unattended access, audio capture, internet relay, accounts, analytics, advertising, or recording.

Review steps:

1. Run Skeldri on a Mac and grant Screen Recording when requested.
2. Run Skeldri on an iPad on the same LAN and select the advertised Mac.
3. Select **Allow** in the Mac menu.
4. Draw with a finger and confirm the vector annotation appears on both devices.
5. Toggle Trackpad mode; if desired, grant Accessibility on the Mac and test pointer, scrolling, and the standard app zoom gesture.
6. Use Back or disconnect; the Mac immediately stops the session and releases held pointer state.

Both the Mac and iPad builds should be reviewed together because neither is useful alone.
