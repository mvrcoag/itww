#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="itww"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ICON_PATH="${ROOT_DIR}/Resources/AppIcon.icns"

echo "==> Building ${APP_NAME} (${CONFIG})..."
cd "${ROOT_DIR}"
swift build --disable-sandbox -c "${CONFIG}"

BIN_PATH="$(swift build --disable-sandbox -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

if [[ ! -f "${ICON_PATH}" ]]; then
    echo "==> Generating AppIcon.icns..."
    swift "${ROOT_DIR}/scripts/generate-icon.swift" "${ICON_PATH}"
fi

echo "==> Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${ICON_PATH}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Prefer a real Apple Development / Developer ID identity (matched by SHA-1 hash to avoid UTF-8 name encoding mismatches)
# so macOS TCC Accessibility permissions persist across rebuilds.
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
SIGN_LABEL=""
if [[ -z "${SIGN_IDENTITY}" ]]; then
    DEV_ID_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application:" | head -n 1 || true)"
    if [[ -n "${DEV_ID_LINE}" ]]; then
        SIGN_IDENTITY="$(echo "${DEV_ID_LINE}" | awk '{print $2}')"
        SIGN_LABEL="$(echo "${DEV_ID_LINE}" | sed -n 's/.*"\(.*\)".*/\1/p')"
    fi
fi
if [[ -z "${SIGN_IDENTITY}" ]]; then
    APPLE_DEV_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development:" | head -n 1 || true)"
    if [[ -n "${APPLE_DEV_LINE}" ]]; then
        SIGN_IDENTITY="$(echo "${APPLE_DEV_LINE}" | awk '{print $2}')"
        SIGN_LABEL="$(echo "${APPLE_DEV_LINE}" | sed -n 's/.*"\(.*\)".*/\1/p')"
    fi
fi

if [[ -n "${SIGN_IDENTITY}" ]]; then
    echo "==> Signing ${APP_BUNDLE} with ${SIGN_LABEL:-$SIGN_IDENTITY}..."
    codesign --force --deep --options runtime \
        --entitlements "${ROOT_DIR}/itww.entitlements" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}"
else
    echo "==> Signing ${APP_BUNDLE} (ad-hoc with identifier com.mvrcoag.itww)..."
    codesign --force --deep \
        --entitlements "${ROOT_DIR}/itww.entitlements" \
        --sign - \
        --identifier "com.mvrcoag.itww" \
        "${APP_BUNDLE}"
fi

echo "==> Built ${APP_BUNDLE}"
echo "Run with: open \"${APP_BUNDLE}\""
