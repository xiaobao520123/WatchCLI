#!/usr/bin/env bash
# Install the iOS companion (and the paired watchOS app it embeds) on a real
# device. Requires that you've signed in to Xcode at least once with an
# Apple ID — the free personal team is fine.
#
# Usage:
#   ./scripts/install-on-device.sh                 # auto-detects connected device
#   ./scripts/install-on-device.sh <device-udid>   # specific device
#
# After install:
#   - The iOS app appears on the iPhone home screen.
#   - The watchOS app installs automatically on the paired Watch (this can
#     take a couple of minutes the first time).

set -euo pipefail
source "$(dirname "$0")/_env.sh"
cd "$REPO_ROOT"

# 1. Pick a connected device.
if [[ $# -ge 1 ]]; then
    DEVICE_UDID="$1"
else
    DEVICE_UDID=$(xcrun devicectl list devices --json-output - 2>/dev/null \
        | python3 -c 'import json,sys; d=json.load(sys.stdin)["result"]["devices"]; \
                       devs=[x for x in d if x.get("connectionProperties",{}).get("tunnelState") in ("connected","unavailable") or "iPhone" in x.get("hardwareProperties",{}).get("productType","")]; \
                       print(devs[0]["hardwareProperties"]["udid"]) if devs else sys.exit(1)' 2>/dev/null || true)
    if [[ -z "$DEVICE_UDID" ]]; then
        DEVICE_UDID=$(xcrun devicectl list devices 2>/dev/null \
            | awk '/connected/ {print $(NF-1)}' | head -1)
    fi
fi

if [[ -z "${DEVICE_UDID:-}" ]]; then
    echo "✗ No connected iPhone detected." >&2
    echo "  Plug it in (or open Settings → Developer Mode → On if it's the first time)," >&2
    echo "  trust this computer, then re-run." >&2
    exit 1
fi
echo "→ device UDID: $DEVICE_UDID"

# 2. Verify signing identity exists; otherwise stop early with friendly help.
IDENTS=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Development\|iPhone Developer\|Apple Distribution" || true)
if [[ "$IDENTS" -eq 0 ]]; then
    cat <<'HELP' >&2
✗ No code-signing identity found in the keychain.

One-time setup (~60 seconds):
  1. Open Xcode.
  2. Xcode → Settings → Accounts.
  3. Click "+", choose "Apple ID", sign in with any Apple ID
     (a free personal team is fine for personal-device installs).
  4. Open WatchCLI.xcodeproj, select the WatchCLI target,
     Signing & Capabilities tab, set "Team" to your personal team.
     Repeat for the "WatchCLI Watch App" target.
  5. Re-run this script.

Tip: edit DEVELOPMENT_TEAM in Project.yml to make this permanent across
xcodegen regenerations.
HELP
    exit 2
fi
echo "→ found $IDENTS code-signing identity/identities"

# 3. Make sure the Xcode project is up to date and build for this device.
xcodegen generate >/dev/null

DEST="platform=iOS,id=$DEVICE_UDID"
echo "→ building WatchCLI for $DEST"
xcodebuild \
    -project WatchCLI.xcodeproj \
    -scheme "WatchCLI" \
    -configuration Release \
    -destination "$DEST" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -skipPackagePluginValidation -skipMacroValidation \
    build 2>&1 | xcbeautify 2>/dev/null || \
xcodebuild \
    -project WatchCLI.xcodeproj \
    -scheme "WatchCLI" \
    -configuration Release \
    -destination "$DEST" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -skipPackagePluginValidation -skipMacroValidation \
    build | tail -5

# 4. Locate the built .app and install it.
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "WatchCLI.app" \
        -path "*Release-iphoneos*" 2>/dev/null \
        | xargs -I{} stat -f "%m %N" {} 2>/dev/null \
        | sort -nr | head -1 | cut -d' ' -f2-)

if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "✗ Could not locate built app under DerivedData/.../Release-iphoneos/" >&2
    exit 3
fi
echo "→ installing $APP"

xcrun devicectl device install app --device "$DEVICE_UDID" "$APP"

echo
echo "✓ iOS app installed."
echo "  The companion watchOS app should mirror to your Apple Watch automatically"
echo "  within a couple of minutes (check the Watch app on your iPhone if not)."