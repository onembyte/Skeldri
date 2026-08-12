#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Repository: $ROOT"
echo "Build directory: $ROOT/.build/DerivedData"
xcodebuild -version
swift --version
echo "macOS SDK: $(xcrun --sdk macosx --show-sdk-version 2>&1)"
echo "iOS Simulator SDK: $(xcrun --sdk iphonesimulator --show-sdk-version 2>&1)"
echo "Devices:"
xcrun xcdevice list 2>/dev/null || true
echo "Schemes:"
xcodebuild -list -project "$ROOT/Skeldri.xcodeproj" 2>/dev/null || true
echo "Signing: simulator builds use CODE_SIGNING_ALLOWED=NO; physical iPad needs a user-selected Team."

