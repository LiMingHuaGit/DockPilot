#!/usr/bin/env bash
# Notarize and staple DockPilot.app for distribution outside the App Store.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. An App Store Connect API key, stored as a notarytool profile:
#        xcrun notarytool store-credentials "dockpilot-notary" \
#            --key /path/to/AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-uuid>
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
#   ./scripts/notarize.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/DockPilot.app"
ZIP="build/DockPilot.zip"
PROFILE="${NOTARY_PROFILE:-dockpilot-notary}"

if [[ ! -d "${APP}" ]]; then
    echo "error: ${APP} not found. Run scripts/build-app.sh with a Developer ID identity first." >&2
    exit 1
fi

echo "==> Zipping for submission"
rm -f "${ZIP}"
/usr/bin/ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Submitting to Apple notary service (profile: ${PROFILE})"
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

echo "==> Stapling ticket"
xcrun stapler staple "${APP}"
xcrun stapler validate "${APP}"

echo "==> Gatekeeper assessment"
spctl --assess --type execute --verbose=4 "${APP}" || true

echo "==> Done. Distribute ${APP} (or re-zip it)."
