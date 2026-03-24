#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/release-config.sh"

APP_PATH="$ROOT/build/${APP_NAME}.app"
PKG_ROOT="$ROOT/build/pkg-root"
UNSIGNED_PKG="$ROOT/build/${APP_NAME}-unsigned.pkg"
SIGNED_PKG="$ROOT/build/${APP_NAME}.pkg"

[[ -d "$APP_PATH" ]] || bash "$ROOT/build-app.sh"

rm -rf "$PKG_ROOT" "$UNSIGNED_PKG" "$SIGNED_PKG"
mkdir -p "$PKG_ROOT/Applications"
cp -R "$APP_PATH" "$PKG_ROOT/Applications/"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$APP_VERSION" \
  "$UNSIGNED_PKG"

if [[ "${SIGN_PKG:-0}" == "1" ]]; then
  productsign \
    --sign "$DEVELOPER_ID_INSTALLER" \
    "$UNSIGNED_PKG" \
    "$SIGNED_PKG"
  rm -f "$UNSIGNED_PKG"
  echo "$SIGNED_PKG"
else
  echo "$UNSIGNED_PKG"
fi
