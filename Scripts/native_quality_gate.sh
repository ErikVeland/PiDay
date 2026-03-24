#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ xcodegen is required to validate the native app release path." >&2
  exit 1
fi

pick_ios_simulator() {
  xcrun simctl list devices available | awk '
    /-- iOS / { ios = 1; next }
    /--/ { ios = 0 }
    ios && /iPhone 16 Pro|iPhone 16|iPhone 17 Pro|iPhone 17/ {
      line = $0
      sub(/^ +/, "", line)
      sub(/ \(.*/, "", line)
      print line
      exit
    }
  '
}

IOS_SIMULATOR="${IOS_SIMULATOR:-$(pick_ios_simulator)}"

if [[ -z "${IOS_SIMULATOR}" ]]; then
  echo "✗ No supported iOS simulator was found. Set IOS_SIMULATOR to override." >&2
  exit 1
fi

echo "▶ Regenerating Xcode project"
if ! ruby -e "require 'xcodeproj'" 2>/dev/null; then
  echo "▶ Installing missing 'xcodeproj' gem..."
  gem install xcodeproj --no-document || sudo gem install xcodeproj --no-document
fi
xcodegen generate

echo "▶ Running PiDay tests on ${IOS_SIMULATOR}"
xcodebuild \
  -scheme PiDay \
  -project PiDay.xcodeproj \
  -destination "platform=iOS Simulator,name=${IOS_SIMULATOR}" \
  test

echo "▶ Building Release configuration without codesigning"
xcodebuild \
  -scheme PiDay \
  -project PiDay.xcodeproj \
  -configuration Release \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "✅ Native quality gate passed"
