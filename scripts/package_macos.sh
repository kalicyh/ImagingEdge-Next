#!/usr/bin/env bash
set -euo pipefail

# macOS packaging script for ImagingEdge Next.
# Builds the Flutter macOS release and produces a DMG using the create-dmg utility.

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

PRODUCT_NAME="ImagingEdge Next"
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
  flutter build macos --release
else
  echo "Skipping flutter build (using existing release build)."
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
cp -R "${APP_PATH}" "${DIST_DIR}/${APP_NAME}"

echo "Packaging complete."
echo "App bundle: ${DIST_DIR}/${APP_NAME}"
echo "DMG image: ${DMG_PATH}"
