#!/bin/sh

# WHY: Xcode Cloud clones a clean copy of the repo, so PiDay.xcodeproj
# (which is gitignored) doesn't exist. This script installs XcodeGen via
# Homebrew and regenerates the project before the build phase runs.
# Xcode Cloud runs ci_post_clone.sh from inside ci_scripts/, so we must
# cd to the repo root (CI_WORKSPACE) where project.yml lives.

set -e

echo "--- Installing XcodeGen ---"
brew install xcodegen

echo "--- Generating Xcode project ---"
# WHY dirname navigation: CI_WORKSPACE may not be set when ci_post_clone.sh
# runs. Navigating relative to the script's own path is always reliable —
# ci_scripts/ is one level below the repo root where project.yml lives.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
echo "Working directory: $REPO_ROOT"

if ! ruby -e "require 'xcodeproj'" 2>/dev/null; then
  echo "--- Installing missing 'xcodeproj' gem ---"
  gem install xcodeproj --no-document --user-install || gem install xcodeproj --no-document
fi

xcodegen generate

echo "--- Done ---"
