#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="$ROOT/.build/DerivedData"
mkdir -p "$DD"
xcodebuild -project "$ROOT/Skeldri.xcodeproj" -scheme SkeldriMac -configuration Debug -destination 'platform=macOS' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project "$ROOT/Skeldri.xcodeproj" -scheme SkeldriPad -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build

