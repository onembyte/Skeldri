# Troubleshooting

- **Screen recording unavailable:** In System Settings, grant DrawPadMac Screen & System Audio Recording access, then relaunch if macOS requests it. DrawPad never changes this setting itself.
- **No Mac appears:** Ensure both devices use the same LAN, permit Local Network access on iPad, and confirm the Mac app is running.
- **Simulator unavailable:** Restart Xcode/CoreSimulator from the GUI. Generic simulator compilation does not require a booted device.
- **Physical-device signing fails:** Select DrawPadiPad → Signing & Capabilities, enable automatic signing, and select your own Team. No team ID is checked in.
- **Xcode says Developer Mode is disabled:** On iPad open Settings → Privacy & Security → Developer Mode, enable it, restart when prompted, and confirm after restart.
- **Installed app will not launch because its developer is untrusted:** On iPad open Settings → General → VPN & Device Management, select the Apple Development profile, and explicitly trust it. Then launch DrawPad again.
- **Video is blank:** Confirm screen recording permission and reconnect so capture/encoder state restarts.
