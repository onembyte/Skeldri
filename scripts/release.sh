#!/usr/bin/env bash
# Builds signed App Store archives of Skeldri for Mac and iPad, exports them,
# and audits the signed products. Nothing leaves this Mac unless --upload is
# given; that flag is the owner's consent to send the build to App Store Connect.
#
# Signing and upload use the Apple ID signed in to Xcode (Settings → Accounts)
# through -allowProvisioningUpdates, so no API key or password is stored here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Skeldri.xcodeproj"
DERIVED_DATA="$ROOT/.build/ReleaseDerivedData"
TEAM_FILE="$ROOT/.build/release-team-id"
EXPORT_TEMPLATE="$ROOT/scripts/ExportOptions-AppStore.plist"

TEAM_ID="${DEVELOPMENT_TEAM:-}"
BUILD_NUMBER=""
PLATFORMS=(mac ipad)
UPLOAD="no"

usage() {
    cat <<'EOF'
Usage: ./scripts/release.sh --build NUMBER [--team TEAM_ID] [--only mac|ipad] [--upload]

Runs the tests, archives SkeldriMac and SkeldriPad with the paid team's
signing, exports App Store packages into .build/Release/<version>-<build>, and
checks their signatures, entitlements, identity, versions, and privacy
manifests.

Rerunning with the same --build and --upload sends exactly the archives that
were checked, without rebuilding them.

  --build NUMBER   CFBundleVersion for this upload; must be higher than every
                   build already uploaded for this version
  --team TEAM_ID   paid Apple Developer Program Team ID (remembered in .build)
  --only PLATFORM  release only mac or ipad
  --upload         upload the checked archives to App Store Connect
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build) [[ $# -ge 2 ]] || { usage; exit 2; }; BUILD_NUMBER="$2"; shift 2 ;;
        --team) [[ $# -ge 2 ]] || { usage; exit 2; }; TEAM_ID="$2"; shift 2 ;;
        --only)
            [[ $# -ge 2 && ( "$2" == mac || "$2" == ipad ) ]] || { usage; exit 2; }
            PLATFORMS=("$2"); shift 2 ;;
        --upload) UPLOAD="yes"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ -z "$TEAM_ID" && -f "$TEAM_FILE" ]]; then
    TEAM_ID="$(<"$TEAM_FILE")"
fi
if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "The paid team's 10-character Team ID is required: --team TEAM_ID" >&2
    exit 2
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "A positive integer build number is required: --build NUMBER" >&2
    exit 2
fi
mkdir -p "$(dirname "$TEAM_FILE")"
printf '%s\n' "$TEAM_ID" > "$TEAM_FILE"

fail() { echo "Release check failed: $*" >&2; exit 1; }

# Note for edits: with pipefail, a reader that stops early (awk `exit`, `head`)
# kills the writer with SIGPIPE and the whole script dies with status 141.
# Readers below consume all input; finds stop with -quit.

# Prints one Release build setting of a scheme, e.g. `setting SkeldriMac PRODUCT_NAME`.
setting() {
    xcodebuild -project "$PROJECT" -scheme "$1" -configuration Release \
        -showBuildSettings 2>/dev/null | \
        awk -F ' = ' -v key="$2" '!found && $1 ~ "^ +" key "$" { print $2; found = 1 }'
}

MARKETING_VERSION="$(setting SkeldriMac MARKETING_VERSION)"
[[ -n "$MARKETING_VERSION" ]] || fail "MARKETING_VERSION could not be read"
[[ "$(setting SkeldriPad MARKETING_VERSION)" == "$MARKETING_VERSION" ]] || \
    fail "SkeldriMac and SkeldriPad have different MARKETING_VERSION values"

scheme_for() { if [[ "$1" == mac ]]; then echo SkeldriMac; else echo SkeldriPad; fi; }

OUT="$ROOT/.build/Release/$MARKETING_VERSION-$BUILD_NUMBER"
ALREADY_CHECKED="no"
if [[ -e "$OUT" ]]; then
    ALREADY_CHECKED="yes"
    for kind in "${PLATFORMS[@]}"; do
        [[ -f "$OUT/$(scheme_for "$kind").checked" ]] || ALREADY_CHECKED="no"
    done
    if [[ "$UPLOAD" != yes || "$ALREADY_CHECKED" != yes ]]; then
        echo "$OUT already exists. App Store Connect never accepts the same build" >&2
        echo "number twice; choose a higher --build, or pass --upload to send the" >&2
        echo "archives that already passed every check." >&2
        exit 1
    fi
fi
mkdir -p "$OUT"

# Writes export options for one destination (export or upload) and prints the path.
export_options() {
    local destination="$1"
    local plist="$OUT/ExportOptions-$destination.plist"
    if [[ ! -f "$plist" ]]; then
        cp "$EXPORT_TEMPLATE" "$plist"
        /usr/libexec/PlistBuddy -c "Set :destination $destination" "$plist"
        /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$plist"
    fi
    printf '%s\n' "$plist"
}

# Audits a signed .app produced by an App Store export.
audit_signed_app() {
    local app="$1" scheme="$2" kind="$3"
    local info entitlements authority
    if [[ "$kind" == mac ]]; then info="$app/Contents/Info.plist"; else info="$app/Info.plist"; fi

    codesign --verify --deep --strict "$app" || fail "$scheme signature does not verify"
    authority="$(codesign -dvv "$app" 2>&1 | awk -F= '!found && /^Authority=/ { print $2; found = 1 }')"
    [[ "$authority" == "Apple Distribution:"* || \
       "$authority" == "3rd Party Mac Developer Application:"* ]] || \
        fail "$scheme is signed by '$authority', not a distribution certificate"

    entitlements="$OUT/$scheme-entitlements.plist"
    codesign -d --entitlements - --xml "$app" > "$entitlements" 2>/dev/null || \
        fail "$scheme entitlements could not be read"
    plutil -lint "$entitlements" >/dev/null || fail "$scheme entitlements are not a valid plist"
    # PlistBuddy, not plutil: plutil reads the dots in entitlement names as key paths.
    entitlement() { /usr/libexec/PlistBuddy -c "Print :$1" "$entitlements" 2>/dev/null || true; }

    [[ "$(entitlement com.apple.developer.team-identifier)" == "$TEAM_ID" ]] || \
        fail "$scheme is not signed for team $TEAM_ID"
    case "$(entitlement get-task-allow)$(entitlement com.apple.security.get-task-allow)" in
        *true*) fail "$scheme is debuggable (get-task-allow); this is not a distribution build" ;;
    esac
    if [[ "$kind" == mac ]]; then
        [[ "$(entitlement com.apple.security.app-sandbox)" == true ]] || fail "SkeldriMac is not sandboxed"
        [[ "$(entitlement com.apple.security.network.server)" == true ]] || \
            fail "SkeldriMac lacks the network server entitlement it needs to listen"
        [[ -z "$(entitlement com.apple.security.network.client)" ]] || \
            fail "SkeldriMac requests outgoing network access it does not need"
        test -f "$app/Contents/Resources/PrivacyInfo.xcprivacy" || fail "SkeldriMac privacy manifest missing"
    else
        test -f "$app/PrivacyInfo.xcprivacy" || fail "SkeldriPad privacy manifest missing"
    fi

    [[ "$(plutil -extract CFBundleIdentifier raw -o - "$info")" == \
       "$(setting "$scheme" PRODUCT_BUNDLE_IDENTIFIER)" ]] || fail "$scheme bundle identifier mismatch"
    [[ "$(plutil -extract CFBundleShortVersionString raw -o - "$info")" == "$MARKETING_VERSION" ]] || \
        fail "$scheme version is not $MARKETING_VERSION"
    [[ "$(plutil -extract CFBundleVersion raw -o - "$info")" == "$BUILD_NUMBER" ]] || \
        fail "$scheme build number is not $BUILD_NUMBER"
    [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$info")" == false ]] || \
        fail "$scheme export-compliance key changed; review it before uploading"
    if xattr -lr "$app" 2>/dev/null | grep -q 'com.apple.quarantine'; then
        fail "$scheme contains a quarantine attribute, which App Store Connect rejects"
    fi

    echo "$scheme: signed by $authority"
    echo "$scheme entitlements:"
    plutil -p "$entitlements" | sed 's/^/    /'
}

release_platform() {
    local kind="$1" scheme destination archive export_dir unpacked package app
    scheme="$(scheme_for "$kind")"
    if [[ "$kind" == mac ]]; then destination='generic/platform=macOS'; else destination='generic/platform=iOS'; fi
    archive="$OUT/$scheme.xcarchive"
    export_dir="$OUT/$scheme-export"
    unpacked="$OUT/$scheme-unpacked"

    echo "Archiving $scheme $MARKETING_VERSION ($BUILD_NUMBER)…"
    xcodebuild -project "$PROJECT" -scheme "$scheme" -configuration Release \
        -destination "$destination" -archivePath "$archive" \
        -derivedDataPath "$DERIVED_DATA" -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" archive

    echo "Exporting $scheme for App Store Connect…"
    xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
        -exportOptionsPlist "$(export_options export)" -allowProvisioningUpdates

    mkdir -p "$unpacked"
    if [[ "$kind" == mac ]]; then
        package="$(find "$export_dir" -maxdepth 1 -name '*.pkg' -print -quit)"
        [[ -n "$package" ]] || fail "no .pkg was exported for $scheme"
        pkgutil --check-signature "$package" | grep -q 'Status: signed' || \
            fail "$scheme installer package is not signed"
        rmdir "$unpacked"
        pkgutil --expand-full "$package" "$unpacked"
    else
        package="$(find "$export_dir" -maxdepth 1 -name '*.ipa' -print -quit)"
        [[ -n "$package" ]] || fail "no .ipa was exported for $scheme"
        ditto -x -k "$package" "$unpacked"
    fi
    app="$(find "$unpacked" -type d -path '*/Payload/*.app' -prune -print -quit)"
    [[ -n "$app" ]] || fail "no app bundle inside $package"
    audit_signed_app "$app" "$scheme" "$kind"
    touch "$OUT/$scheme.checked"
    echo "$scheme package: $package"
}

if [[ "$ALREADY_CHECKED" != yes ]]; then
    echo "Running tests…"
    "$ROOT/scripts/test.sh"
    for kind in "${PLATFORMS[@]}"; do
        release_platform "$kind"
    done
fi

if [[ "$UPLOAD" != yes ]]; then
    echo
    echo "All checks passed for $MARKETING_VERSION ($BUILD_NUMBER). Nothing was uploaded."
    echo "Packages are in $OUT."
    echo "To send exactly these archives: ./scripts/release.sh --build $BUILD_NUMBER --upload"
    exit 0
fi

for kind in "${PLATFORMS[@]}"; do
    scheme="$(scheme_for "$kind")"
    echo "Uploading $scheme $MARKETING_VERSION ($BUILD_NUMBER) to App Store Connect…"
    xcodebuild -exportArchive -archivePath "$OUT/$scheme.xcarchive" \
        -exportPath "$OUT/$scheme-upload" \
        -exportOptionsPlist "$(export_options upload)" -allowProvisioningUpdates
done

echo
echo "Uploaded. App Store Connect e-mails when processing finishes; the builds"
echo "then appear under TestFlight for internal testers."
