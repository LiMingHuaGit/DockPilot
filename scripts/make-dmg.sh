#!/usr/bin/env bash
# Package build/DockPilot.app into a drag-to-install DMG.
#
#   ./scripts/make-dmg.sh
#   SIGN_IDENTITY="Apple Development: ..." ./scripts/make-dmg.sh
#
# Output: build/DockPilot-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DockPilot"
APP="build/${APP_NAME}.app"
STAGING="build/dmg-staging"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist 2>/dev/null || echo 1.0.0)"
DMG="build/${APP_NAME}-${VERSION}.dmg"

# Ensure the app exists (build + sign it if not).
if [[ ! -d "${APP}" ]]; then
    echo "==> ${APP} not found; building it first"
    ./scripts/build-app.sh
fi

echo "==> Preparing staging folder"
rm -rf "${STAGING}" "${DMG}"
mkdir -p "${STAGING}"
cp -R "${APP}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"

echo "==> Creating DMG (${DMG})"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${DMG}" >/dev/null

rm -rf "${STAGING}"

# Sign the DMG itself if a real identity is provided (ad-hoc "-" is skipped).
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    echo "==> Signing DMG (identity: ${SIGN_IDENTITY})"
    codesign --force --sign "${SIGN_IDENTITY}" "${DMG}"
fi

echo "==> Done: ${DMG}"
ls -lh "${DMG}"
