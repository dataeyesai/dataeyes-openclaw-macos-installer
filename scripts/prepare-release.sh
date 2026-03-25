#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="$ROOT/dataeyes-macos-app"
ARTIFACTS_DIR="$ROOT/artifacts"
LOCAL_RELEASE_DIR="$ROOT/release"

. "$APP_ROOT/release-config.sh"

VERSION="${RELEASE_VERSION:-$APP_VERSION}"
BUILD_ARTIFACTS="${BUILD_ARTIFACTS:-0}"
GENERATED_AT="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

ZIP_SOURCE="$APP_ROOT/build/${APP_NAME}.zip"
DMG_SOURCE="$APP_ROOT/build/${APP_NAME}.dmg"
PKG_SOURCE="$APP_ROOT/build/${APP_NAME}-unsigned.pkg"

ZIP_TARGET="$ARTIFACTS_DIR/${APP_NAME}.zip"
DMG_TARGET="$ARTIFACTS_DIR/${APP_NAME}.dmg"
PKG_TARGET="$ARTIFACTS_DIR/${APP_NAME}-unsigned.pkg"
CHECKSUM_FILE="$ARTIFACTS_DIR/SHA256SUMS.txt"
MANIFEST_FILE="$ARTIFACTS_DIR/RELEASE_MANIFEST.md"
NOTES_FILE="$LOCAL_RELEASE_DIR/release-notes-v${VERSION}.md"

require_artifact() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required artifact: $path" >&2
    exit 1
  fi
}

ensure_built_artifacts() {
  local needs_build=0

  for path in "$ZIP_SOURCE" "$DMG_SOURCE" "$PKG_SOURCE"; do
    if [[ ! -f "$path" ]]; then
      needs_build=1
      break
    fi
  done

  if [[ "$BUILD_ARTIFACTS" == "1" || "$needs_build" == "1" ]]; then
    bash "$APP_ROOT/build-app.sh"
    bash "$APP_ROOT/build-dmg.sh"
    bash "$APP_ROOT/build-pkg.sh"
  fi
}

file_size_bytes() {
  stat -f '%z' "$1"
}

file_size_mb() {
  local bytes
  bytes="$(file_size_bytes "$1")"
  awk -v bytes="$bytes" 'BEGIN { printf "%.2f MiB", bytes / 1024 / 1024 }'
}

file_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

write_checksums() {
  cat > "$CHECKSUM_FILE" <<EOF
$(file_sha256 "$ZIP_TARGET")  $(basename "$ZIP_TARGET")
$(file_sha256 "$DMG_TARGET")  $(basename "$DMG_TARGET")
$(file_sha256 "$PKG_TARGET")  $(basename "$PKG_TARGET")
EOF
}

write_manifest() {
  cat > "$MANIFEST_FILE" <<EOF
# Release Manifest

- Generated at: ${GENERATED_AT}
- Version: ${VERSION}
- Build: ${APP_BUILD}
- Bundle ID: ${APP_BUNDLE_ID}
- Minimum macOS: ${APP_MIN_MACOS}
- Architectures: ${APP_ARCHS}

## Files

| File | Size | SHA256 |
| --- | --- | --- |
| $(basename "$ZIP_TARGET") | $(file_size_mb "$ZIP_TARGET") | $(file_sha256 "$ZIP_TARGET") |
| $(basename "$DMG_TARGET") | $(file_size_mb "$DMG_TARGET") | $(file_sha256 "$DMG_TARGET") |
| $(basename "$PKG_TARGET") | $(file_size_mb "$PKG_TARGET") | $(file_sha256 "$PKG_TARGET") |

## Notes

- \`.dmg\` is the recommended distribution format for end users.
- \`.zip\` is useful for directly distributing the app bundle.
- The app bundle is built as a universal binary for Apple Silicon and Intel Macs.
- The app bundle is ad-hoc signed to avoid the broken-bundle "damaged" error.
- \`.pkg\` is currently unsigned unless you rebuild and sign it explicitly.
EOF
}

write_release_notes() {
  mkdir -p "$LOCAL_RELEASE_DIR"

  cat > "$NOTES_FILE" <<EOF
# DataEyes OpenClaw macOS Installer v${VERSION}

## Highlights

- Supports both China and Global platform configuration
- Auto-detects the real model list available to the provided API key and injects it into OpenClaw
- Lets users refresh models later with \`~/.dataeyes-openclaw/bin/dataeyes-refresh-models\`
- Adds a clearer installer UI with step progress, heartbeat status, and cleaned logs
- Builds a universal app for both Apple Silicon and Intel Macs
- Fixes the broken bundle signature that previously caused macOS to report the app as damaged
- Fixes paste behavior in the macOS password field
- Forces gateway service refresh during install to reduce \`loaded but stopped\`
- Reads the live gateway token from \`~/.openclaw/openclaw.json\`
- Opens \`http://localhost:18789/#token=...\` automatically after install

## Downloads

- \`$(basename "$DMG_TARGET")\` - recommended for general users
- \`$(basename "$ZIP_TARGET")\` - direct app bundle distribution
- \`$(basename "$PKG_TARGET")\` - unsigned PKG for internal testing or later signing

## Checksums

\`\`\`text
$(cat "$CHECKSUM_FILE")
\`\`\`

## Notes

- This build fixes the broken package issue, but Gatekeeper may still warn because it is not Developer ID signed and notarized yet.
- For public distribution, prefer a signed and notarized \`.dmg\` or \`.pkg\`.
EOF
}

main() {
  if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_NAME}" == v* ]]; then
    if [[ "${GITHUB_REF_NAME#v}" != "$VERSION" ]]; then
      echo "Tag ${GITHUB_REF_NAME} does not match APP_VERSION ${VERSION}" >&2
      exit 1
    fi
  fi

  mkdir -p "$ARTIFACTS_DIR"
  ensure_built_artifacts

  require_artifact "$ZIP_SOURCE"
  require_artifact "$DMG_SOURCE"
  require_artifact "$PKG_SOURCE"

  cp -f "$ZIP_SOURCE" "$ZIP_TARGET"
  cp -f "$DMG_SOURCE" "$DMG_TARGET"
  cp -f "$PKG_SOURCE" "$PKG_TARGET"

  write_checksums
  write_manifest
  write_release_notes

  echo "Prepared release files:"
  printf ' - %s\n' "$ZIP_TARGET" "$DMG_TARGET" "$PKG_TARGET" "$CHECKSUM_FILE" "$MANIFEST_FILE" "$NOTES_FILE"
}

main "$@"
