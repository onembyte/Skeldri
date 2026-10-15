#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/.build/doctor"
mkdir -p "$LOG_DIR"

run_probe() {
  local label="$1"
  local log="$2"
  shift 2
  if "$@" >"$log" 2>&1; then
    cat "$log"
    return 0
  else
    local status=$?
    echo "$label failed (exit $status). Details: $log"
    tail -n 12 "$log" 2>/dev/null || true
    return 0
  fi
}

echo "Repository: $ROOT"
echo "Build directory: $ROOT/.build/DerivedData"
xcodebuild -version
swift --version
echo "macOS SDK: $(xcrun --sdk macosx --show-sdk-version 2>&1)"
echo "iOS Simulator SDK: $(xcrun --sdk iphonesimulator --show-sdk-version 2>&1)"
echo "Simulator service:"
if xcrun simctl list runtimes >"$LOG_DIR/simulator.txt" 2>&1; then
  echo "Healthy"
else
  status=$?
  echo "Unhealthy (exit $status). Restart the Mac if simdiskimaged is unresponsive."
  tail -n 8 "$LOG_DIR/simulator.txt" 2>/dev/null || true
fi
echo "Devices:"
run_probe "Device discovery" "$LOG_DIR/devices.txt" xcrun xcdevice list
echo "Schemes:"
run_probe "Project inspection" "$LOG_DIR/project.txt" xcodebuild -list -project "$ROOT/Skeldri.xcodeproj"
echo "Signing: simulator builds use CODE_SIGNING_ALLOWED=NO; physical iPad needs a user-selected Team."
