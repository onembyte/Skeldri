# App Store Release Checklist

Skeldri has two modern distribution bundles: `com.onembyte.skeldri.mac` and `com.onembyte.skeldri.ipad`. This repository does not upload or publish either app.

## Automated release audit

```bash
./scripts/test.sh
./scripts/build.sh
./scripts/release-audit.sh
```

The last command creates unsigned Release archives under `.build/Archives` and checks bundle identity, versions, architectures, privacy manifests, export-compliance declarations, and quarantine attributes.

## App Store Connect preparation

- Create the two explicit App IDs and corresponding Mac/iPad records.
- Set version `1.0`, build `1`, categories, age rating, support URL, screenshots, and the public HTTPS privacy-policy URL.
- Answer App Privacy with “Data Not Collected”; the app has no tracking.
- Use the reviewer notes in `APP_REVIEW_NOTES.md` and provide both apps for review together.
- Archive using the current App Store-required Xcode/SDK, select the paid distribution Team, validate, and inspect signing before upload.
- Do not add Accessibility, camera, microphone, location, or audio entitlements.

## Physical release gate

- Approve and reject a modern iPad session from the Mac menu.
- Confirm no video/input is exchanged before approval.
- Validate drawing, display switching, Trackpad mode, disconnect, reconnect, and shutdown.
- Repeat approval, mirroring, drawing, and reconnect with Skeldri Afi.
- Confirm the Mac sandbox permits Bonjour, ScreenCaptureKit, and the consented CGEvent path.

The public privacy URL, paid-team signing, App Store validation, screenshots, metadata, and upload are manual owner actions.
