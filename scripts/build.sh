#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_env.sh"
cd "$REPO_ROOT"

echo "→ swift build (daemon + protocol)"
swift build

echo "→ regenerating Xcode project"
xcodegen generate

echo "→ building iOS companion app"
xcodebuild -project WatchCLI.xcodeproj -scheme "WatchCLI" \
    -destination "generic/platform=iOS Simulator" -configuration Debug \
    -skipPackagePluginValidation -skipMacroValidation \
    CODE_SIGNING_ALLOWED=NO build -quiet

echo "→ building watchOS app"
xcodebuild -project WatchCLI.xcodeproj -scheme "WatchCLI Watch App" \
    -destination "generic/platform=watchOS Simulator" -configuration Debug \
    -skipPackagePluginValidation -skipMacroValidation \
    CODE_SIGNING_ALLOWED=NO build -quiet

echo "✓ all targets built"
