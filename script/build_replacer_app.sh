#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ReplaceCodexGauge"
MIN_SYSTEM_VERSION="13.0"
BUILD_TARGET="$(uname -m)-apple-macosx${MIN_SYSTEM_VERSION}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/native/ReplaceCodexGauge.swift"
BUILD_DIR="$ROOT_DIR/native/build"
APP_BUNDLE="$ROOT_DIR/native/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SWIFT_MODULE_CACHE="$BUILD_DIR/swift-module-cache"
CLANG_MODULE_CACHE="$BUILD_DIR/clang-module-cache"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

SWIFT_MODULE_CACHE_PATH="$SWIFT_MODULE_CACHE" \
CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE" \
  swiftc -target "$BUILD_TARGET" "$SOURCE_FILE" -o "$APP_BINARY" -framework Cocoa
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>app.codexgauge.replacer</string>
  <key>CFBundleName</key>
  <string>Replace Codex Gauge</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>ReplaceRootDir</key>
  <string>$ROOT_DIR</string>
</dict>
</plist>
PLIST

strip_metadata() {
  xattr -cr "$APP_BUNDLE" 2>/dev/null || true
  xattr -d -r com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
  xattr -d -r com.apple.fileprovider.fpfs#P "$APP_BUNDLE" 2>/dev/null || true
  xattr -d -r com.apple.provenance "$APP_BUNDLE" 2>/dev/null || true
}

verify_signed_bundle() {
  local target="$1"
  local tmp_parent
  local clean_target
  local status=0
  tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-replacer-verify.XXXXXX")"
  clean_target="$tmp_parent/$(basename "$target")"
  ditto --norsrc --noextattr "$target" "$clean_target" || status=$?
  if [[ "$status" -eq 0 ]]; then
    codesign --verify --deep --strict "$clean_target" || status=$?
  fi
  rm -rf "$tmp_parent"
  return "$status"
}

strip_metadata
codesign --force --sign - "$APP_BUNDLE"
strip_metadata
verify_signed_bundle "$APP_BUNDLE"

printf "%s\n" "$APP_BUNDLE"
