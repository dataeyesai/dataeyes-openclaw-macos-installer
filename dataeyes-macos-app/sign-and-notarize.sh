#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/release-config.sh"

ARTIFACT_TYPE="${1:-app}"
ARTIFACT_PATH="${2:-}"

sign_app() {
  local app_path="$1"
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APP" \
    "$app_path"
}

submit_for_notary() {
  local path="$1"
  xcrun notarytool submit "$path" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
}

case "$ARTIFACT_TYPE" in
  app)
    APP_PATH="${ARTIFACT_PATH:-$ROOT/build/${APP_NAME}.app}"
    ZIP_PATH="$ROOT/build/${APP_NAME}-signed.zip"
    sign_app "$APP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
    submit_for_notary "$ZIP_PATH"
    xcrun stapler staple "$APP_PATH"
    echo "$APP_PATH"
    ;;
  dmg)
    DMG_PATH="${ARTIFACT_PATH:-$ROOT/build/${APP_NAME}.dmg}"
    submit_for_notary "$DMG_PATH"
    xcrun stapler staple "$DMG_PATH"
    echo "$DMG_PATH"
    ;;
  pkg)
    PKG_PATH="${ARTIFACT_PATH:-$ROOT/build/${APP_NAME}.pkg}"
    submit_for_notary "$PKG_PATH"
    xcrun stapler staple "$PKG_PATH"
    echo "$PKG_PATH"
    ;;
  *)
    echo "Usage: $0 <app|dmg|pkg> [path]" >&2
    exit 1
    ;;
esac
