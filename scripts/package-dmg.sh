#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="itww"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${ROOT_DIR}/Info.plist")"
DMG_NAME="${APP_NAME}-${VERSION}-macOS-arm64.dmg"
DMG_LATEST="${APP_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}-macOS-arm64.zip"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/itww-dmg.XXXXXX")"

cleanup() {
    rm -rf "${STAGE_DIR}"
}
trap cleanup EXIT

"${ROOT_DIR}/scripts/build-app.sh" release

echo "==> Staging DMG contents..."
cp -R "${APP_BUNDLE}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

rm -f "${DMG_PATH}" "${BUILD_DIR}/${DMG_LATEST}" "${ZIP_PATH}"

echo "==> Creating compressed disk image ${DMG_PATH}..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGE_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

cp "${DMG_PATH}" "${BUILD_DIR}/${DMG_LATEST}"

echo "==> Creating notarization/release archive ${ZIP_PATH}..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Packaging complete:"
echo "  App: ${APP_BUNDLE}"
echo "  DMG: ${DMG_PATH}"
echo "  DMG (latest alias): ${BUILD_DIR}/${DMG_LATEST}"
echo "  ZIP: ${ZIP_PATH}"
