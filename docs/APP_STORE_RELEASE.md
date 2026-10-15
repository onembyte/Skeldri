# App Store Release Checklist

Skeldri ships as one App Store record: the Mac and iPad apps share the bundle identifier `com.onembyte.skeldri` (universal purchase). The step-by-step release checklist is [RELEASE_PLAN.md](RELEASE_PLAN.md).

## Signed App Store builds

```bash
./scripts/release.sh --team TEAM_ID --build 1          # archive, export, check; uploads nothing
./scripts/release.sh --build 1 --upload                # upload exactly those checked archives
```

`release.sh` runs the tests, archives both apps with the paid team's automatic signing, exports App Store packages to `.build/Release/<version>-<build>`, and refuses to continue unless each signed app verifies, is signed by a distribution certificate for that team, is not debuggable, keeps the Mac sandbox and network-server entitlements, carries its privacy manifest, matches the expected bundle identifier, version, build number, and export-compliance key, and has no quarantine attribute. Signing and upload use the Apple ID signed in to Xcode; no API key or password is stored. Every upload needs a build number higher than any already sent for that version.

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
- Produce the submission archive with a non-beta Xcode release. The current machine has Xcode 27 beta, which is suitable for compatibility testing but not a final App Store upload artifact.
- Do not add Accessibility, camera, microphone, location, or audio entitlements.

## Physical release gate

- Approve and reject a modern iPad session from the Mac menu.
- Confirm no video/input is exchanged before approval.
- Validate drawing, display switching, Trackpad mode, disconnect, reconnect, and shutdown.
- Repeat approval, mirroring, drawing, and reconnect with Skeldri Afi.
- Confirm the Mac sandbox permits Bonjour, ScreenCaptureKit, and the consented CGEvent path.

The public privacy URL, paid-team signing, App Store validation, screenshots, metadata, and upload are manual owner actions.
