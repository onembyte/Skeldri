# Skeldri 1.0 Release Plan

Created 2026-10-09 from a full audit of Skeldri (Mac and iPad) and Skeldri Afi.
It supersedes the owner-action list in `APP_STORE_RELEASE.md`, which stays as
background.

**How to use this file.** Work one unchecked item at a time, top to bottom.
**GATE** means stop and get Franco's answer before going past it. Each item names
who does it:

- **[F]** is Franco: the Apple account, money, legal, anything machine-wide,
  privacy settings, and every upload.
- **[C]** is Claude: repo work, using TDD for code.

Code changes start with a failing test.

## Where things stand

| App | Store | Bundle ID today | Minimum OS | State |
|---|---|---|---|---|
| Skeldri for Mac (`SkeldriMac`) | Mac App Store | `com.onembyte.skeldri` (was `.mac`) | macOS 15 | Feature-complete; Read mode not yet verified on hardware |
| Skeldri for iPad (`SkeldriPad`) | App Store | `com.onembyte.skeldri` (was `.ipad`) | iPadOS 18 | Feature-complete; Read mode not yet verified on hardware |
| Skeldri Afi (separate repo) | Sideload only | `com.onembyte.skeldri.afi` | iOS 10, armv7 | Works on the iPad 4 (A1458) |

### Facts that shape the plan

1. **The iPad 4 cannot get any app from the App Store.** Since 2026-04-28,
   uploads must be built with Xcode 26 or later and the iOS 26 SDK. Current Xcode
   cannot link 32-bit `armv7`, and its lowest deployment target is iOS 15. "Old
   iPads" on the App Store therefore means the iPads stuck on iPadOS 15–17:
   - Stuck on iPadOS 15: iPad Air 2, iPad mini 4.
   - Stuck on iPadOS 16: iPad 5, iPad Pro 9.7", iPad Pro 12.9" (1st gen).
   - Stuck on iPadOS 17: iPad 6, iPad Pro 10.5", iPad Pro 12.9" (2nd gen).

   The iPad 4 and the A7 iPads (Air 1, mini 2 and 3) stay sideload-only.
2. **There is no Xcode on this Mac.** It has only the Command Line Tools, and the
   Xcode 27 beta that was used before is gone. Only 11 GB is free on `/`.
   - App Store Connect rejects builds made with a beta Xcode.
   - Xcode 27 (released) runs on macOS 26.6 or later, so it runs here (macOS 27.2).
3. **Only one signing identity exists, and it belongs to the free Personal Team.**
   No team is set in `project.yml`, and `release-audit.sh` archives unsigned.
   There is no ExportOptions file and no upload path.
4. **The Personal Team may hold the current bundle IDs.** It already provisioned
   `.mac`, `.ipad` and `.afi`. If so, the paid team can get "identifier not
   available" when it registers them.
5. **Apps built with the iOS 27 SDK must use the UIScene life cycle (TN3187), or
   they crash at launch.** SkeldriPad already does (SwiftUI App). Skeldri Afi does
   not (`AFIAppDelegate.m`, no scene manifest).
6. **TestFlight on iPad requires iPadOS 16 or later.** An iPadOS 15 build cannot be
   tested on an iPadOS 15 device through TestFlight.
7. **The release code is not on `main`.** Two draft PRs are open:
   - Skeldri #2: `agent/personal-install`, 56 commits ahead of `main`, which is
     where the Afi listener lives.
   - Afi #1: `agent/app-store-security`.
8. **Two checklists are still open.** Read mode is code-complete but untested on
   hardware, and the regression sweep for Draw and Trackpad has not been run.
   Both are in Gates B and F of `RECOVERY_AND_LECTURE_CHECKLIST.md`.
9. **The transport is plain TCP.** Approval on the Mac stops accidental use, but
   not an active attacker on the same LAN (`SECURITY_AUDIT.md`, residual risks).
   An approved session carries pointer control.

## GATE 0 — decisions (D1 and D2 are needed before the first upload)

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | How old iPads are served | **Decided 2026-10-09.** No App Store build for old iPads. SkeldriPad stays at iPadOS 18. Skeldri Afi is installed over USB by a script in its repo, with instructions (Phase 1.E). | — |
| D2 | Bundle IDs | **Decided 2026-10-09: one App Store record "Skeldri".** Mac and iPad share `com.onembyte.skeldri` (universal purchase). | — **This cannot be changed after the first upload.** The paid team must register the ID before anything is signed with it (0.E). |
| D3 | Price | Free / paid / free with paid features later | Franco's call. Paid needs the Paid Apps Agreement, tax and banking. Under the EU DSA, a paid app almost certainly means declaring trader status, which publishes an address and phone number in the EU. |
| D4 | Hosting for the privacy policy and support page, plus a contact | **(a)** Self-hosted on `francomichetti.com` (TrueNAS + Cloudflare Tunnel, like the portfolio). **(b)** GitHub Pages from the public Skeldri repo. That site already exists at `onembyte.github.io/Skeldri`, served from `main:/docs`. | **(a)**: self-hosted and private by default. The trade-off is uptime: App Review and users need the URLs to resolve, and that depends on the NAS. The support contact (which email address) is needed either way. |
| D5 | The Afi compatibility listener in the store Mac build | **(a)** Keep it, as an "Allow older iPads" setting that is off by default, and disclose it in the review notes. **(b)** Compile it out of the store build. **(c)** Leave it as it is today: always on and undocumented. | **(a)**, and D1 makes it necessary: the USB-installed Afi only works if the App Store Mac app still listens for it. Nothing extra listens by default, and nothing is hidden from review (Guideline 2.3.1). With (b), the iPad 4 would need a separately signed Mac build that clashes with the store copy. **Working assumption until Franco says otherwise.** |
| D6 | Transport security in 1.0 | **(a)** Ship plain TCP with clear disclosure. **(b)** Before 1.0, add authenticated encryption to the modern Mac↔iPad channels: TLS 1.3 in Network.framework, with a key from a pairing code shown on the Mac. | **(b)**, because an approved session can drive the pointer. This is the largest Phase 1 item. Afi stays plain TCP, behind the D5 opt-in. Export compliance must be re-answered: OS-provided TLS is normally exempt, but verify. Choosing (a) is acceptable if the description promises nothing about security and states "trusted networks". |
| D7 | Zoom through ⌘+ / ⌘− keystrokes | **(a)** Keep it, but look up the keys from the current keyboard layout. The hard-coded ANSI key codes 24 and 27 fire other shortcuts on Spanish and German layouts. **(b)** Remove pinch-zoom in Trackpad mode for 1.0. | **(a)**, if Phase 1 testing on Franco's own keyboard layout confirms the bug and the fix. It stays disclosed in the review notes. It does conflict with the AGENTS.md "no keyboard control" rule, so Franco should confirm the exception explicitly. |
| D9 | The Linux host on `main` (added 2026-08-25) | **(a)** Ship 1.0 for Mac and iPad only. In README and on the landing page, mark the Linux host as not yet compatible with Skeldri 1.0 for iPad. **(b)** Port the Linux host to protocol 7 before launch. | **(a)** for 1.0, (b) as follow-up work. The Linux host speaks DrawPad protocol 2 and advertises `_drawpad._tcp`, so the 1.0 iPad app (protocol 7, `_skeldri._tcp`) cannot even find it. Yet `onembyte.github.io/Skeldri` publicly advertises "Linux and macOS". If D6(b) adds encryption, the Linux host must adopt it too. |
| D8 | Read mode in 1.0 | Ship it after the Phase 1 hardware checks pass / hide it behind a build flag for 1.0 | Test first (Phase 1). Hide it only if it fails Gate F. |

Also needed from Franco:
- The paid **Team ID** and the entity type (Individual or Organization). The
  seller name shown on the store comes from this.
- Confirmation that the app name "Skeldri" is free in App Store Connect.

## Phase 0 — First internal TestFlight build

Goal: both apps installed from TestFlight on Franco's own Mac and iPad.

### 0.A Account

- [ ] [F] Check that the membership is active. Note the Team ID and entity type.
- [ ] [F] In App Store Connect → Business, accept the current agreements. Add the
      Paid Apps Agreement, tax and banking only if D3 is paid.
- [x] [F] Decide D1 (2026-10-09: USB install only for old iPads).
- [x] [F] Decide D2 (2026-10-09: universal purchase, `com.onembyte.skeldri`).
- [x] [F] Decide D9 (2026-10-09: 1.0 is Mac and iPad only).
- [ ] [F] D3–D8 (see the table) can wait until Phase 1 but must be settled
      before Phase 2.

### 0.B Toolchain

- [x] [F/C] Free disk space. Xcode 27, the iPadOS platform and one iPad
      simulator need about 25–30 GB. On 2026-10-09 the Afi Xcode 9 toolchain
      (6.2 GB) was offloaded to the NAS as a verified tar, bringing free space to
      22 GB. More room if needed: `~/.cache/kolk-vendor-recovery` (4.2 GB),
      `~/dev/archive`, `brew cleanup`, all Franco's call.
- [x] [F/C] Install Xcode. **Xcode 27.1 RC** (27A9275, 2026-10-05) was
      downloaded on 2026-10-09 and expanded into `/Applications`; its `.xip`
      goes to the NAS. Apple accepts Release Candidate builds for TestFlight and
      submission, but not betas. This Mac runs macOS 27.2 beta 3, whose matching
      Xcode 27.2 beta cannot upload. Before the Phase 2 submission, check whether
      27.1 has shipped final and re-archive with it if the build differs. Open it once and let
      it install its components. Add the Apple ID under Settings → Accounts and
      download the iPadOS platform.
- [x] [F] Point the command line at it with
      `sudo xcode-select -s /Applications/Xcode.app` (a machine-wide change, so
      Franco runs it). The alternative is for Claude to prefix every command with
      `DEVELOPER_DIR`.
- [x] [C] Run `./scripts/doctor.sh`, `./scripts/test.sh`, `./scripts/build.sh` and
      `./scripts/release-audit.sh` on the released Xcode. Record the toolchain in
      `docs/ENVIRONMENT.md`. Done 2026-10-10 on Xcode 27.1 RC: 83 tests pass, both
      apps build, and the unsigned audit passes. The five iOS 18
      deprecation warnings in `iPadOS/Video/H264Decoder.swift` are fixed: the
      decoder now calls its layer's `sampleBufferRenderer` directly. Both apps
      build with zero warnings. The video path gets re-checked on the device in
      1.C.

### 0.C Repo baseline (merges need Franco's yes)

- [x] [C] Merge `origin/main` into `release/1.0`. Main can't fast-forward: it
      gained the Linux host, installer and landing page on 2026-08-25. The merge
      conflicts only in `README.md`, whose wording depends on D9. **GATE: D9.**
- [ ] [C] Review and refresh Skeldri PR #2. **[F]** approves before `main` moves.
      Note that `main:/docs` is published by GitHub Pages at
      `onembyte.github.io/Skeldri`: every file merged into `docs/` becomes a
      public web page.
- [x] [C] Branch `release/1.0`. It was created from the PR #2 head, which `main`
      fast-forwards to. All release work below happens there.
- [ ] [C] Afi: review PR #1 (`agent/app-store-security`). It fast-forwards `main`.
      On 2026-10-09 its host tests passed and its armv7 link was verified. The
      device Allow/Reject/reconnect check is still open (Phase 1.E); **[F]**
      approves the merge after that.

### 0.D Release configuration [C]

Config changes; script changes get a dry run.

- [x] Add the paid `DEVELOPMENT_TEAM` to both app targets in `project.yml` (M3A5V2ZKZ4, Individual). A team
      ID is not secret, and the setting survives `xcodegen generate`.
- [x] Set the bundle IDs according to D2. With (a), both targets use
      `com.onembyte.skeldri`.
- [x] Add `MARKETING_VERSION: 1.0` and `CURRENT_PROJECT_VERSION` to `project.yml`.
      Change both Info.plists to `$(MARKETING_VERSION)` /
      `$(CURRENT_PROJECT_VERSION)`. Make `release-audit.sh` compare against the
      build settings instead of the literals "1.0" / "1".
- [x] Set the Mac `PRODUCT_NAME` to `Skeldri`. Today Finder, Spotlight and the
      privacy panes all show "SkeldriMac". Update `release-audit.sh` and
      `install-personal.sh` to match.
- [x] Add `ExportOptions-AppStore.plist` with:
      - `method` = `app-store-connect`
      - `destination` = `upload`
      - `signingStyle` = `automatic`
      - `teamID`
      - `uploadSymbols` = true
- [x] Add `scripts/release.sh`. It runs tests, then a signed Release archive per
      platform, then checks the signed product:
      - entitlements are sandbox + network only, with no `get-task-allow`;
      - `codesign --verify --deep --strict` passes;
      - no `com.apple.quarantine` attribute;
      - the privacy manifest is present.

      It then validates. It uploads only with an explicit `--upload` flag. The
      build number is passed in and must increase with every upload.
- [x] Regenerate `Skeldri.xcodeproj`, then commit `project.yml` together with the
      project file. XcodeGen 2.46.0 reproduces the committed project exactly.
- [x] [C] After 0.B: compile and run every script on the released Xcode. The
      0.D changes compile, test and archive. `release.sh` is first run in 0.F.
- [x] Switch `install-personal.sh` to the paid team. Development profiles then
      last 1 year instead of 7 days, and that also covers the Afi sideload on the
      iPad 4.

### 0.E App Store Connect records [F]

- [ ] Register the App ID(s). If Xcode or the portal says "not available", it is
      fact 4: **GATE**. Pick a new ID or contact Developer Support.
- [ ] Create the record:
      - name "Skeldri";
      - primary language English (U.S.);
      - bundle ID per D2;
      - SKU, e.g. `SKELDRI-1`.

      With D2(a), add the macOS platform to the same record. If the name is
      taken: **GATE**.

### 0.F Build and upload (Claude runs it; Franco says go before each upload)

- [x] [C] Run `scripts/release.sh` for the Mac, then the iPad: archive and check.
      Done 2026-10-10. Both are signed `Apple Distribution: FRANCO MICHETTI
      (M3A5V2ZKZ4)`. The signing registered `com.onembyte.skeldri` under the
      paid team with no identifier clash. Entitlements are minimal: Mac sandbox +
      network client/server; iPad distribution only. Packages are 2.6 MB (Mac)
      and 1.5 MB (iPad).
- [ ] [C] Upload build 1.0 (1) with `./scripts/release.sh --build 1 --upload`.
      This needs the App Store Connect record from 0.E.
- [ ] [F] Wait for processing. Export compliance is answered by the plist key.
      Create an internal TestFlight group containing Franco, and fill in "What to
      Test".

### 0.G Install from TestFlight [F]

- [ ] Quit the personal-install Skeldri, then remove `/Applications/Skeldri.app`.
      The new signer resets the Screen Recording and Accessibility grants. That
      reset is the first-run test.
- [ ] Install from TestFlight.app on the Mac and from TestFlight on the iPad 7th
      gen (iPadOS 18.6.2).
- [ ] **GATE 0 passes** when both store-signed apps launch, connect, mirror and
      draw.

## Phase 1 — Test and corrections

Every defect becomes a failing test first, then a fix, then a new build number
and a TestFlight upload. Repeat until the backlog's must-fix rows are closed.

### 1.A Test matrix

| Surface | Device / OS | Covers | Gap |
|---|---|---|---|
| Mac | This Mac, macOS 27.2 **beta** | everything | No released macOS 15 or 26. Use external TestFlight testers, or Franco runs a macOS VM if disk allows. |
| iPad | iPad 7th gen, iPadOS 18.6.2 | minimum OS for (c); non-glass fallback | none |
| iPad | iPad Pro 13" simulator, iPadOS 27 | Liquid Glass, windowed multitasking, screenshots | Simulator only. Test there that it discovers the Mac. |
| Afi | iPad 4 A1458, iOS 10.3.3, installed over USB | D5 listener against the store Mac build; the 1.E install script | — |

### 1.B Reviewer simulation [F]

- [ ] On a **new macOS user account**, so no privacy settings are reset, follow
      `APP_REVIEW_NOTES.md` word for word with the TestFlight builds.
- [ ] Note every point where a stranger would be stuck: no visible window,
      prompts without context, an empty iPad list.

### 1.C Acceptance sweep [F with C]

- [ ] The whole of `MANUAL_TESTING.md`.
- [ ] Gate B of `RECOVERY_AND_LECTURE_CHECKLIST.md` (regression of Draw and
      Trackpad).
- [ ] The open item in Gate D: portrait/landscape and light/dark.
- [ ] Gate F: Read mode legibility, pacing, memory, bitrate, delay, thermals,
      minimize/hide/Spaces, reconnect. This decides D8.
- [ ] Zoom on Franco's own keyboard layout. This decides D7.

### 1.D Correction backlog from the 2026-10-09 audit

Must-fix before Phase 2:

| ID | App | Problem | Evidence | Fix |
|---|---|---|---|---|
| M1 | Mac | Menu-bar-only app: a reviewer launches it and sees nothing, and the icon can hide behind the notch | `macOS/Info.plist` `LSUIElement`; only `MenuBarExtra` | First-run window explaining the menu-bar icon, the permissions and the need for the iPad app; an About item |
| M2 | Mac | Screen Recording prompt appears at launch, before the user has asked for anything | `SkeldriMacApp.swift:223` → `DisplayManager.swift:7` | Enumerate displays only after `CGPreflightScreenCaptureAccess()` succeeds or the user presses Grant |
| M3 | Mac | Accessibility prompt has no in-app explanation | `MacMainView.swift:35`, `MacInputController.swift:19-26` | Explanation sheet before `CGRequestPostEventAccess()` |
| M4 | Mac | Hard-coded ANSI key codes for zoom | `MacInputController.swift:123-131` | Per D7 |
| M5 | Mac | Afi listener always on, and not in the review notes | `SkeldriMacApp.swift:216`, `Info.plist` `_skeldri-afi._tcp` | Per D5 |
| P1 | iPad | Denying Local Network permission leaves an endless spinner, with no Settings link | `iPadNetworkClient.swift:98-103` handles only `.failed`; `PeerConnection.swift:42` | Searching / denied / failed states; detect `.waiting(PolicyDenied)`; button to `openSettingsURLString` |
| P2 | iPad | Empty list never says a Mac app is needed (Guideline 4.2 risk) | `DiscoveryView.swift:70-89` | "Open Skeldri on your Mac on the same Wi-Fi", plus troubleshooting after about 10 s |
| P3 | iPad | "Awaiting approval" can hang forever, with no Cancel | `SkeldriPadApp.swift:124`, `DiscoveryView.swift:152` | Cancel button; client-side timeout; treat `.waiting` as a failure |
| P4 | iPad | Toolbar about 730 pt wide clips in Split View, Slide Over and iPadOS 26 windows; Back sits under the window controls | `DrawingToolbar.swift:11-56`, `DrawingScreen.swift:161-176` | Compact-width layout; respect the top safe area |
| R1 | Both | Docs disagree with the code | `APP_REVIEW_NOTES.md:5` says "one display" and "no key events" | Rewrite after D5, D7 and D8 |

Should-fix:

| ID | App | Problem | Fix |
|---|---|---|---|
| S1 | Mac | Opaque full-bleed square icon looks wrong next to macOS rounded icons | Rebuild with the macOS template or Icon Composer |
| S2 | Mac | `Host.current().localizedName` can stall the main thread at launch (`MacNetworkServer.swift:50`) | `NWListener.Service(name: nil)` |
| S3 | Mac | `network.client` entitlement may be unnecessary | Remove it if Phase 1 shows the Mac never connects out |
| S4 | iPad | Jargon errors such as "Incompatible protocol version", plus "Unknown error" (`SkeldriPadApp.swift:26,274`) | "Update Skeldri on both devices." |
| S5 | iPad | Discovery is not refreshed when the app returns to the foreground (`SkeldriPadApp.swift:19-22`) | Refresh on `.active` |
| S6 | iPad | White flash at launch; "Pull to refresh" text at about 2.5:1 contrast; "Colour" and "Color" both used | Set `UIColorName` on the launch screen; raise the contrast; use one spelling |
| S7 | iPad | Fixed font sizes ignore Dynamic Type | Do not claim Dynamic Type support in App Store Connect for 1.0 |

### 1.E Skeldri Afi USB install (D1)

This is checked to be possible as of 2026-10-09:
- The Xcode 9.4.1 compiler runs under Rosetta and its armv7 SDK is intact in
  `SkeldriAfi/.build/toolchain-stage`.
- The previous install on the iPad 4 used third-party tools (pymobiledevice3, and
  Impactor, which takes the Apple ID login). The new path uses only Apple tools.
- `xcrun devicectl` cannot be used: in practice it only reaches iOS 17 and later.

Steps:
- [ ] [F] Once a year, in the developer portal:
      - register the iPad 4's UDID;
      - register the App ID `com.onembyte.skeldri.afi` under the paid team;
      - create an iOS **Development** profile that contains that iPad and the
        paid team's Apple Development certificate, and download it.
- [ ] [C] Build the armv7 app once with `build-armv7-direct.sh`. Keep the
      **unsigned** `.ipa` as a versioned release artifact, so that later installs
      need no Xcode 9 and no Rosetta. Apple keeps general Rosetta only through
      macOS 27.
- [ ] [C] Write `scripts/install-usb.sh` in the SkeldriAfi repo. It:
      - checks the profile (expiry, team, App ID, and that the connected iPad's
        UDID is in it);
      - embeds the profile and re-signs with `codesign` using the profile's
        entitlements;
      - packages an `.ipa`;
      - installs it with Apple Configurator's `cfgutil install-app`, or, if
        `cfgutil` is missing, prints the Finder drag-and-drop steps.
- [ ] [F with C] On the real iPad 4, test which Apple install path still works
      with iOS 10.3.3: `cfgutil`, then Finder. **GATE** if neither does. The
      fallback is pymobiledevice3, which is third-party and needs Franco's yes.
- [ ] [C] Add the instructions to the SkeldriAfi README:
      - the cable;
      - trusting the Mac;
      - the yearly profile;
      - turning on "Allow older iPads" on the Mac.
- [ ] [C] Note the device boundary: an armv7 build runs only on iPads on iOS 10
      or earlier. Adding an arm64 slice later could also cover iPads stuck on
      iOS 11–17. Optional and not planned.

### 1.F Transport security (per D6(b)) [C]

- [ ] Write a threat model and protocol design in `docs/PROTOCOL.md` first:
      - pairing code shown on the Mac;
      - TLS 1.3 with a pre-shared key on both TCP channels;
      - session binding.

      Bump the protocol version.
- [ ] TDD the key derivation and handshake state machine, then integrate. Afi
      stays plain TCP, behind the D5 opt-in.
- [ ] Re-answer export compliance and update `SECURITY.md` and
      `SECURITY_AUDIT.md`.

### 1.G External TestFlight dry run (recommended)

- [ ] [F] Create an external group with 1–3 testers, ideally including someone on
      released macOS and someone with an old iPad.
- [ ] [F] The first build goes through Beta App Review, which gives an early read
      on Guidelines 4.2, 2.1 and 5.1.1 before the real submission.

This needs the D4 contact and URLs early.

### 1.H Release candidate [C]

- [ ] Tests green; `release.sh` checks pass on the signed archives.
- [ ] Update `ARCHITECTURE.md`, `PROTOCOL.md` and `IMPLEMENTATION_STATUS.md`
      (required by AGENTS.md), and add a 1.0.0 entry to `CHANGELOG.md`.
- [ ] Tag `v1.0.0-rcN`.
- [ ] **GATE 1**: Franco signs off on the RC build numbers.

## Phase 2 — Publish

### 2.A Public pages

- [ ] [C] Update `PRIVACY_POLICY.md` to reflect the final behaviour:
      - window capture in Read mode;
      - the D5 opt-in;
      - the D6 encryption statement;
      - the contact.
- [ ] [C/F] Publish the privacy policy and a support page at HTTPS URLs (D4).
      Check that both load from outside the LAN.

### 2.B Store listing

- [ ] [C] Finalize `APP_STORE_METADATA.md`:
      - descriptions with no "securely" claim unless D6(b) shipped;
      - a mention of Read mode;
      - promo text;
      - keywords (100 characters, no trademarks);
      - subtitle;
      - copyright "© 2026 Franco Michetti".
- [ ] [F] Capture the screenshots on a clean demo desktop with no names, email or
      network details:
      - iPad 13" at 2064×2752 (or landscape), from the iPadOS 27 simulator
        connected to the Mac;
      - Mac at 2880×1800 or 2560×1600.

      A preview video is optional.
- [ ] [F] Record a 60–90 s demo video of Mac and iPad together: approve, draw,
      Trackpad, Read, disconnect. Attach it under App Review Information as a file,
      not a public link.
- [ ] [C] Final `APP_REVIEW_NOTES.md`:
      - both platforms are in the same submission;
      - local network only (Guideline 4.2.7);
      - every permission and why;
      - the zoom keystroke;
      - the compatibility listener.

### 2.C Compliance in App Store Connect [F]

- [ ] Age rating questionnaire (the 2026 system).
- [ ] App Privacy: Data Not Collected; no tracking.
- [ ] Price and countries (D3).
- [ ] Turn off "iPad app on Apple silicon Mac" and visionOS availability.
- [ ] Content rights.
- [ ] Categories: Graphics & Design, then Utilities.
- [ ] EU DSA trader status (D3).
- [ ] Release method: **manual**.

### 2.D Submit and release

- [ ] [F] Submit the Mac and iPad versions in **one** submission. On rejection:
      fix through the Phase 1 loop, reply in Resolution Center, resubmit.
- [ ] [F] When both are approved, release them manually at the same moment.

### 2.E After release [C]

- [ ] Tag `v1.0.0` on `main` and merge `release/1.0`.
- [ ] Update the README: remove the "not submitted" note and add the store links.
- [ ] Update `IMPLEMENTATION_STATUS.md`.
- [ ] [F] Expire the old TestFlight builds. Watch crashes in Xcode Organizer
      (Apple only; no third-party SDK).

## Risks

| Risk | Mitigation |
|---|---|
| Guideline 4.2: the iPad app is useless without the Mac | P2 copy; one submission; demo video; universal purchase |
| Mac review scrutinizes Accessibility, Screen Recording and keystrokes | M2/M3 explanations; D7; precise review notes; demo video |
| Bundle IDs held by the Personal Team | D2(a) uses a new ID; register at the start of 0.E |
| No testing on released macOS 15/26 | External TestFlight testers, or a macOS VM if disk allows |
| A future macOS drops Rosetta, so Xcode 9 can no longer rebuild Afi | Keep the unsigned armv7 `.ipa` as a release artifact; re-signing needs only `codesign` (1.E) |
| A LAN attacker can hijack an approved session | D6 |
| Low disk space blocks Xcode | 0.B first; keep DerivedData in `.build/` and clean it |
| The build Mac runs a macOS beta | Uploads only check the Xcode/SDK build; still test on a released macOS (1.A) |

## Rules this plan follows

- **No commit trailers.** Skeldri is a public repo with no workflows, so no
  `[skip ci]`. SkeldriAfi is private but also has no workflows.
- **Git hygiene.** Stage named paths only. Run `git fetch` and `git status` before
  every commit.
- **Franco only:**
  - anything machine-wide (Xcode install, `xcode-select`, user accounts);
  - privacy-settings resets;
  - App Store Connect;
  - every upload;
  - merges to `main`.
