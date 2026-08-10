#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="$ROOT/.build/DerivedData"
mkdir -p "$DD"
xcodebuild -project "$ROOT/DrawPad.xcodeproj" -scheme DrawPadTests -configuration Debug -destination 'platform=macOS' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO test

