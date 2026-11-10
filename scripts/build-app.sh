#!/usr/bin/env bash
# Build DockPilot.app from the SwiftPM release binary and (optionally) code-sign it.
#
#   ./scripts/build-app.sh                 # ad-hoc signed, for local use
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
#
# The resulting bundle is written to build/DockPilot.app
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DockPilot"
BUNDLE="build/${APP_NAME}.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # default: ad-hoc

echo "==> swift build -c release"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

echo "==> Assembling ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BIN_PATH}/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp scripts/Info.plist "${BUNDLE}/Contents/Info.plist"

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${BUNDLE}/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> Code signing (identity: ${SIGN_IDENTITY})"
# --timestamp needs network and is only required for notarization; enable with TIMESTAMP=1.
TS_FLAG="--timestamp=none"
if [[ "${TIMESTAMP:-0}" == "1" ]]; then TS_FLAG="--timestamp"; fi
codesign --force --options runtime ${TS_FLAG} \
    --sign "${SIGN_IDENTITY}" "${BUNDLE}"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "${BUNDLE}"

echo "==> Done: ${BUNDLE}"
