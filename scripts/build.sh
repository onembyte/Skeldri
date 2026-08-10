#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="$ROOT/.build/DerivedData"
mkdir -p "$DD"
xcodebuild -project "$ROOT/DrawPad.xcodeproj" -scheme DrawPadMac -configuration Debug -destination 'platform=macOS' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project "$ROOT/DrawPad.xcodeproj" -scheme DrawPadiPad -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build

