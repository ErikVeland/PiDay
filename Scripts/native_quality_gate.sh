#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ xcodegen is required to validate the native app release path." >&2
  exit 1
fi

pick_ios_simulator() {
  # WHY priority list then any-iPhone fallback:
  # CI runners (GitHub macos-15) may only have the iOS SDK that shipped with the
  # pinned Xcode version. Preferred models come first; if none match we fall back
  # to the first available iPhone simulator so CI never fails due to a missing model.
  xcrun simctl list devices available 2>/dev/null | awk '
    /-- iOS / { ios = 1; next }
    /-- / { ios = 0 }
    ios && /iPhone 17 Pro[^M]|iPhone 17[^P ]|iPhone 16 Pro[^M]|iPhone 16[^P ]/ {
      line = $0
      sub(/^ +/, "", line)
      sub(/ \(.*/, "", line)
      print line
      exit
    }
  ' || true

  # Fallback: grab the first available iPhone of any model
  xcrun simctl list devices available 2>/dev/null | awk '
    /-- iOS / { ios = 1; next }
    /-- / { ios = 0 }
    ios && /iPhone/ {
      line = $0
      sub(/^ +/, "", line)
      sub(/ \(.*/, "", line)
      print line
      exit
    }
  ' || true
}

IOS_SIMULATOR="${IOS_SIMULATOR:-}"
if [[ -z "${IOS_SIMULATOR}" ]]; then
  IOS_SIMULATOR="$(pick_ios_simulator | head -1)"
fi

if [[ -z "${IOS_SIMULATOR}" ]]; then
  echo "✗ No iOS simulator found. Set IOS_SIMULATOR to override." >&2
  exit 1
fi

echo "▶ Regenerating Xcode project"
if ! ruby -e "require 'xcodeproj'" 2>/dev/null; then
  echo "▶ Installing missing 'xcodeproj' gem..."
  gem install xcodeproj --no-document --user-install 2>/dev/null \
    || gem install xcodeproj --no-document
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
