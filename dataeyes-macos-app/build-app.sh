#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/release-config.sh"

APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_DIR="$ROOT/Sources/DataEyesInstallerApp"
ICON_PATH="$ROOT/build/${APP_ICON_NAME}.icns"
UNIVERSAL_BIN="$MACOS_DIR/DataEyesInstaller"
SLICE_DIR="$ROOT/build/slices"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$SLICE_DIR"
mkdir -p "$SLICE_DIR"

bash "$ROOT/scripts/create-iconset.sh" >/dev/null

build_slice() {
  local arch="$1"
  local output_path="$SLICE_DIR/DataEyesInstaller-$arch"

  swiftc \
    -O \
    -target "${arch}-apple-macos${APP_MIN_MACOS}" \
    -framework AppKit \
    -framework Foundation \
    "$SOURCE_DIR/main.swift" \
    -o "$output_path"
}

build_binary() {
  local built_slices=()
  local arch

  for arch in $APP_ARCHS; do
    build_slice "$arch"
    built_slices+=("$SLICE_DIR/DataEyesInstaller-$arch")
  done

  if [[ "${#built_slices[@]}" -eq 1 ]]; then
    cp "${built_slices[0]}" "$UNIVERSAL_BIN"
  else
    lipo -create "${built_slices[@]}" -output "$UNIVERSAL_BIN"
  fi
}

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>DataEyesInstaller</string>
  <key>CFBundleIconFile</key>
  <string>${APP_ICON_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${APP_BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>${APP_CATEGORY}</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${APP_MIN_MACOS}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

build_binary

cp -R "$PAYLOAD_SOURCE" "$RESOURCES_DIR/payload"
cp "$ICON_PATH" "$RESOURCES_DIR/${APP_ICON_NAME}.icns"
chmod +x "$RESOURCES_DIR/payload/双击开始安装.command" \
  "$RESOURCES_DIR/payload/内部文件/安装主程序.sh" \
  "$RESOURCES_DIR/payload/内部文件/安装OpenClaw基础环境.sh" \
  "$RESOURCES_DIR/payload/内部文件/scripts/dataeyes-setup.sh" \
  "$RESOURCES_DIR/payload/内部文件/scripts/dataeyes-verify.sh"

# Re-sign the assembled bundle after all resources have been copied in.
# This avoids the broken linker-only signature that causes Gatekeeper to
# report the app as damaged.
codesign --force --deep --sign - "$APP_DIR"

echo "Built app:"
echo "$APP_DIR"

ZIP_PATH="$ROOT/build/${APP_NAME}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
echo "Packaged zip:"
echo "$ZIP_PATH"
