#!/bin/sh

# WHY: Xcode Cloud clones a clean copy of the repo, so PiDay.xcodeproj
# (which is gitignored) doesn't exist. This script installs XcodeGen via
# Homebrew and regenerates the project before the build phase runs.
# Xcode Cloud automatically executes ci_pre_xcodebuild.sh before every build.

set -e

echo "--- Installing XcodeGen ---"
brew install xcodegen

echo "--- Generating Xcode project ---"
xcodegen generate

echo "--- Done ---"
