#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/release-config.sh"

APP_PATH="$ROOT/build/${APP_NAME}.app"
DMG_TEMP="$ROOT/build/${APP_NAME}-temp.dmg"
DMG_PATH="$ROOT/build/${APP_NAME}.dmg"
STAGING_DIR="$ROOT/build/dmg-root"

[[ -d "$APP_PATH" ]] || bash "$ROOT/build-app.sh"

rm -rf "$STAGING_DIR" "$DMG_TEMP" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
