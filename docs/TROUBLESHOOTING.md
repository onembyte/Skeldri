# Troubleshooting

- **Screen recording unavailable:** In System Settings, grant DrawPadMac Screen & System Audio Recording access, then relaunch if macOS requests it. DrawPad never changes this setting itself.
- **No Mac appears:** Ensure both devices use the same LAN, permit Local Network access on iPad, and confirm the Mac app is running.
- **A Mac appears twice:** Pull down on the discovery list to refresh. Current builds deduplicate advertisements using a stable Bonjour identity and prohibit multiple Mac instances; quit any older DrawPadMac processes left running from a development build.
- **Simulator unavailable:** Restart Xcode/CoreSimulator from the GUI. Generic simulator compilation does not require a booted device.
- **Physical-device signing fails:** Select DrawPadiPad → Signing & Capabilities, enable automatic signing, and select your own Team. No team ID is checked in.
- **Personal install asks for a Team ID:** In Xcode, open DrawPadiPad → Signing & Capabilities and read the selected Team. Run `./scripts/install-personal.sh --team TEAM_ID --device "Your iPad Name"` once; the values are stored only in `.build`.
- **Personal iPad app stops opening after a week:** Free Personal Team provisioning profiles expire after 7 days. Reconnect the iPad and rerun `./scripts/install-personal.sh` to rebuild, reinstall, and relaunch both apps.
- **Personal installer cannot find the iPad:** Unlock it, reconnect USB, accept any trust prompt, confirm Developer Mode is enabled, and pass the exact name shown by `xcrun xcdevice list` with `--device`.
- **Xcode says Developer Mode is disabled:** On iPad open Settings → Privacy & Security → Developer Mode, enable it, restart when prompted, and confirm after restart.
- **Installed app will not launch because its developer is untrusted:** On iPad open Settings → General → VPN & Device Management, select the Apple Development profile, and explicitly trust it. Then launch DrawPad again.
- **Video is blank:** Confirm screen recording permission and reconnect so capture/encoder state restarts.
- **Video becomes delayed:** Current protocol-4 builds bound end-to-end video buffering and recover at a forced keyframe. Confirm both devices were installed together, reconnect, and inspect Mac Console logs for `Video metrics` or `screenshot fallback`; a protocol mismatch is reported instead of silently connecting.
- **Trackpad does not move the Mac pointer:** Open the DrawPad menu-bar popover and select **Grant Pointer Permission**, then approve DrawPad in the macOS privacy prompt. If macOS requests it, quit and reopen DrawPadMac. Screen Recording permission does not grant pointer control.
- **Mac and iPad report incompatible versions:** Trackpad support requires protocol 4. Rebuild/install both applications together with `./scripts/install-personal.sh`.
