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
# WHY CI_WORKSPACE: Xcode Cloud sets this env var to the repo root.
# xcodegen must run from the directory containing project.yml.
cd "$CI_WORKSPACE"
xcodegen generate

echo "--- Done ---"
