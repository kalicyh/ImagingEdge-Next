#!/usr/bin/env bash
set -euo pipefail

# macOS release packaging script for ImagingNext.
# Builds the Flutter macOS release (unless skipped) and produces a DMG using create-dmg.
# Copies the resulting .app bundle and gathers Android release artifacts into the dist directory.

usage() {
  cat <<USAGE
Usage: ${0##*/} [--skip-build]

Options:
  --skip-build   Use the existing macOS release build instead of running flutter build.
  --help         Show this help message.
USAGE
}

SKIP_BUILD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/macos/Build/Products/Release"
APPINFO_FILE="${PROJECT_ROOT}/macos/Runner/Configs/AppInfo.xcconfig"

PRODUCT_NAME="ImagingNext"
if [[ -f "${APPINFO_FILE}" ]]; then
  CONFIG_VALUE="$(grep -E '^\s*PRODUCT_NAME\s*=' "${APPINFO_FILE}" | tail -1 | cut -d'=' -f2-)"
  if [[ -n "${CONFIG_VALUE}" ]]; then
    PRODUCT_NAME="$(echo "${CONFIG_VALUE}" | xargs)"
  fi
fi

APP_NAME="${PRODUCT_NAME}.app"
APP_PATH="${BUILD_DIR}/${APP_NAME}"
DIST_DIR="${PROJECT_ROOT}/dist/macos"
DMG_BASE="${PRODUCT_NAME//[ _]/-}"
DMG_NAME="${DMG_BASE}-macOS.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
ANDROID_DIST_DIR="${PROJECT_ROOT}/dist/android"
ANDROID_APK_PATH="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
ANDROID_AAB_PATH="${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab"

command -v flutter >/dev/null 2>&1 || {
  echo "Error: flutter command not found in PATH." >&2
  exit 1
}

command -v create-dmg >/dev/null 2>&1 || {
  echo "Error: create-dmg command not found." >&2
  echo "Install it via \"npm install --global create-dmg\"." >&2
  exit 1
}

if [[ "${SKIP_BUILD}" == false ]]; then
  echo "Building Flutter release artifacts..."
  flutter build macos --release
  flutter build apk --release
  flutter build appbundle --release
else
  echo "Skipping Flutter builds (using existing release artifacts)."
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: macOS app bundle not found at ${APP_PATH}" >&2
  exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

create-dmg \
  --overwrite \
  --no-version-in-filename \
  --dmg-title "${PRODUCT_NAME}" \
  "${APP_PATH}" \
  "${TMP_DIR}" >/dev/null

DMG_SOURCE="$(find "${TMP_DIR}" -maxdepth 1 -type f -name '*.dmg' | head -n 1)"
if [[ -z "${DMG_SOURCE}" ]]; then
  echo "Error: create-dmg did not produce a DMG file." >&2
  exit 1
fi

mv "${DMG_SOURCE}" "${DMG_PATH}"
# cp -R "${APP_PATH}" "${DIST_DIR}/${APP_NAME}"

echo "macOS packaging complete."
# echo "  App bundle: ${DIST_DIR}/${APP_NAME}"
echo "  DMG image: ${DMG_PATH}"

mkdir -p "${ANDROID_DIST_DIR}"
COPIED_ANDROID=false

if [[ -f "${ANDROID_APK_PATH}" ]]; then
  cp "${ANDROID_APK_PATH}" "${ANDROID_DIST_DIR}/app-release.apk"
  echo "Copied Android APK to ${ANDROID_DIST_DIR}/app-release.apk"
  COPIED_ANDROID=true
else
  echo "Android APK not found at ${ANDROID_APK_PATH}; skipping copy."
fi

if [[ -f "${ANDROID_AAB_PATH}" ]]; then
  cp "${ANDROID_AAB_PATH}" "${ANDROID_DIST_DIR}/app-release.aab"
  echo "Copied Android AAB to ${ANDROID_DIST_DIR}/app-release.aab"
  COPIED_ANDROID=true
else
  echo "Android App Bundle not found at ${ANDROID_AAB_PATH}; skipping copy."
fi

if [[ "${COPIED_ANDROID}" == false ]]; then
  echo "No Android release artifacts were copied. Run 'flutter build apk --release' or 'flutter build appbundle --release' first."
fi
