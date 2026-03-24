#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/release-config.sh"

TMP_DIR="$ROOT/build/iconset"
ICONSET_DIR="$TMP_DIR/${APP_ICON_NAME}.iconset"
ICNS_PATH="$ROOT/build/${APP_ICON_NAME}.icns"

rm -rf "$TMP_DIR"
mkdir -p "$ICONSET_DIR"

swift "$ROOT/scripts/generate-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

echo "$ICNS_PATH"
