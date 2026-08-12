#!/usr/bin/env bash
# Builds and inspects unsigned App Store-shaped archives. This script never
# signs, exports, validates with App Store Connect, or uploads an artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/.build/ReleaseDerivedData"
ARCHIVES="$ROOT/.build/Archives"
MAC_ARCHIVE="$ARCHIVES/SkeldriMac.xcarchive"
PAD_ARCHIVE="$ARCHIVES/SkeldriPad.xcarchive"

mkdir -p "$DERIVED_DATA" "$ARCHIVES"

ENTITLEMENTS="$ROOT/macOS/SkeldriMac.entitlements"
for key in \
  com.apple.security.app-sandbox \
  com.apple.security.network.client \
  com.apple.security.network.server; do
  if [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS")" != "true" ]]; then
    echo "Required Mac entitlement is missing or disabled: $key" >&2
    exit 1
  fi
done

if [[ "$(xcodebuild -project "$ROOT/Skeldri.xcodeproj" -scheme SkeldriMac \
  -configuration Release -showBuildSettings 2>/dev/null | \
  awk -F ' = ' '/ENABLE_HARDENED_RUNTIME/ { print $2; exit }')" != "YES" ]]; then
  echo "Hardened Runtime must be enabled for the Mac Release configuration" >&2
  exit 1
fi

xcodebuild -project "$ROOT/Skeldri.xcodeproj" -scheme SkeldriMac \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$MAC_ARCHIVE" -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO archive

xcodebuild -project "$ROOT/Skeldri.xcodeproj" -scheme SkeldriPad \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$PAD_ARCHIVE" -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO archive

MAC_APP="$MAC_ARCHIVE/Products/Applications/SkeldriMac.app"
PAD_APP="$PAD_ARCHIVE/Products/Applications/SkeldriPad.app"
MAC_PLIST="$MAC_APP/Contents/Info.plist"
PAD_PLIST="$PAD_APP/Info.plist"

test -d "$MAC_APP" && test -d "$PAD_APP"
test -f "$MAC_APP/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$PAD_APP/PrivacyInfo.xcprivacy"
plutil -lint "$MAC_PLIST" "$PAD_PLIST" \
  "$MAC_APP/Contents/Resources/PrivacyInfo.xcprivacy" "$PAD_APP/PrivacyInfo.xcprivacy"

for manifest in \
  "$MAC_APP/Contents/Resources/PrivacyInfo.xcprivacy" \
  "$PAD_APP/PrivacyInfo.xcprivacy"; do
  grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$manifest"
  grep -q 'CA92.1' "$manifest"
  grep -q 'NSPrivacyAccessedAPICategorySystemBootTime' "$manifest"
  grep -q '35F9.1' "$manifest"
done

test "$(plutil -extract CFBundleIdentifier raw -o - "$MAC_PLIST")" = "com.onembyte.skeldri.mac"
test "$(plutil -extract CFBundleIdentifier raw -o - "$PAD_PLIST")" = "com.onembyte.skeldri.ipad"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$MAC_PLIST")" = "1.0"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$PAD_PLIST")" = "1.0"
test "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$MAC_PLIST")" = "false"
test "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$PAD_PLIST")" = "false"
test -n "$(plutil -extract NSScreenCaptureUsageDescription raw -o - "$MAC_PLIST")"
test -n "$(plutil -extract NSLocalNetworkUsageDescription raw -o - "$MAC_PLIST")"
test -n "$(plutil -extract NSLocalNetworkUsageDescription raw -o - "$PAD_PLIST")"

file "$MAC_APP/Contents/MacOS/SkeldriMac" | grep -q 'arm64'
file "$PAD_APP/SkeldriPad" | grep -q 'arm64'

if xattr -lr "$MAC_APP" "$PAD_APP" 2>/dev/null | grep -q 'com.apple.quarantine'; then
  echo "Release archive contains a forbidden quarantine attribute" >&2
  exit 1
fi

echo "Release audit passed"
echo "Mac archive: $MAC_ARCHIVE"
echo "iPad archive: $PAD_ARCHIVE"
