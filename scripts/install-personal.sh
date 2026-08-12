#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_ROOT="$ROOT/.build/PersonalInstall"
DERIVED_DATA="$INSTALL_ROOT/DerivedData"
TEAM_FILE="$ROOT/.build/personal-team-id"
DEVICE_FILE="$ROOT/.build/personal-device-name"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
DEVICE_NAME="${SKELDRI_DEVICE:-${DRAWPAD_DEVICE:-}}"

usage() {
    cat <<'EOF'
Usage: ./scripts/install-personal.sh [--team TEAM_ID] [--device "Device Name"]

Builds Release versions of both apps, installs SkeldriPad on a connected
personal device, packages SkeldriMac, and launches both apps.

The Team ID and device name are saved only under the ignored .build directory.
Apple Personal Team provisioning expires after 7 days; rerun this command to
refresh the iPad installation.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            TEAM_ID="$2"
            shift 2
            ;;
        --device)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            DEVICE_NAME="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$TEAM_ID" && -f "$TEAM_FILE" ]]; then
    TEAM_ID="$(<"$TEAM_FILE")"
fi
if [[ -z "$DEVICE_NAME" && -f "$DEVICE_FILE" ]]; then
    DEVICE_NAME="$(<"$DEVICE_FILE")"
fi

if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "A 10-character Apple Team ID is required." >&2
    echo "Run once with: ./scripts/install-personal.sh --team TEAM_ID --device \"Your iPad\"" >&2
    exit 2
fi
if [[ -z "$DEVICE_NAME" ]]; then
    echo "A connected iPad name is required." >&2
    echo "Run once with: ./scripts/install-personal.sh --team TEAM_ID --device \"Your iPad\"" >&2
    exit 2
fi

mkdir -p "$INSTALL_ROOT" "$(dirname "$TEAM_FILE")"
printf '%s\n' "$TEAM_ID" > "$TEAM_FILE"
printf '%s\n' "$DEVICE_NAME" > "$DEVICE_FILE"

echo "Building SkeldriMac (Release)…"
xcodebuild \
    -project "$ROOT/Skeldri.xcodeproj" \
    -scheme SkeldriMac \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    build

echo "Building SkeldriPad (Release, Personal Team)…"
xcodebuild \
    -project "$ROOT/Skeldri.xcodeproj" \
    -scheme SkeldriPad \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    build

MAC_APP="$DERIVED_DATA/Build/Products/Release/SkeldriMac.app"
IPAD_APP="$DERIVED_DATA/Build/Products/Release-iphoneos/SkeldriPad.app"
MAC_ARCHIVE="$INSTALL_ROOT/SkeldriMac.zip"

[[ -d "$MAC_APP" ]] || { echo "Mac build product was not found." >&2; exit 1; }
[[ -d "$IPAD_APP" ]] || { echo "iPad build product was not found." >&2; exit 1; }

# Read the identifier from the bundle that was just built. Hard-coding it here
# silently broke launching after the DrawPad rename: the install succeeded and
# only the launch failed, reporting the app as "not installed".
IPAD_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$IPAD_APP/Info.plist")"
[[ -n "$IPAD_BUNDLE_ID" ]] || { echo "The iPad bundle identifier could not be read." >&2; exit 1; }

ditto -c -k --sequesterRsrc --keepParent "$MAC_APP" "$MAC_ARCHIVE"

echo "Installing SkeldriPad on ${DEVICE_NAME}…"
xcrun devicectl device install app --device "$DEVICE_NAME" "$IPAD_APP"

echo "Launching SkeldriMac…"
# `open` reuses an existing application process even when its on-disk binary was
# just replaced. That can leave the Mac and iPad speaking different protocol
# versions after an upgrade, so terminate only SkeldriMac and wait for its clean
# shutdown before launching the newly built bundle.
if pgrep -x SkeldriMac >/dev/null || pgrep -x DrawPadMac >/dev/null; then
    killall SkeldriMac 2>/dev/null || true
    killall DrawPadMac 2>/dev/null || true
    for _ in {1..50}; do
        if ! pgrep -x SkeldriMac >/dev/null && ! pgrep -x DrawPadMac >/dev/null; then break; fi
        sleep 0.1
    done
fi
if pgrep -x SkeldriMac >/dev/null || pgrep -x DrawPadMac >/dev/null; then
    echo "The previous Mac companion did not stop; quit it from the menu bar and rerun this installer." >&2
    exit 1
fi
open -n "$MAC_APP"

echo "Launching SkeldriPad…"
if ! xcrun devicectl device process launch --device "$DEVICE_NAME" "$IPAD_BUNDLE_ID"; then
    echo "The app was installed, but iPadOS could not launch it automatically." >&2
    echo "Unlock the iPad and open Skeldri manually." >&2
fi

echo
echo "Personal installation complete."
echo "Mac app: $MAC_APP"
echo "Mac archive: $MAC_ARCHIVE"
echo "Rerun this script before the 7-day Personal Team profile expires."
