#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexGauge"
LEGACY_APP_NAME="AiLimitStatus"
BUNDLE_ID="app.codexgauge.menubar"
MIN_SYSTEM_VERSION="13.0"
APP_VERSION="0.9.3"
APP_BUILD="1"
RELEASE_URL="https://github.com/qingzhangeddie-byte/codex-gauge/releases"
UPDATE_TEAM_ID="${CODEX_GAUGE_UPDATE_TEAM_ID:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/native/CodexGauge.swift"
DIST_DIR="$ROOT_DIR/native/dist"
BUILD_DIR="$ROOT_DIR/native/build"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY_NAME="$APP_NAME"
LEGACY_APP_BINARY_NAME="${APP_NAME}-bin"
APP_BINARY="$APP_MACOS/$APP_BINARY_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SWIFT_MODULE_CACHE="$BUILD_DIR/swift-module-cache"
CLANG_MODULE_CACHE="$BUILD_DIR/clang-module-cache"
AGENT_LABEL="app.codexgauge.menubar"
AGENT_PLIST="$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"

launchctl_domain() {
  printf "gui/%s" "$(id -u)"
}

unload_launch_agent() {
  /bin/launchctl bootout "$(launchctl_domain)/$AGENT_LABEL" >/dev/null 2>&1 || true
}

stop_app() {
  unload_launch_agent
  rm -rf "$LEGACY_SUPPORT_DIR" >/dev/null 2>&1 || true
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -x "$LEGACY_APP_BINARY_NAME" >/dev/null 2>&1 || true
  pkill -x "$LEGACY_APP_NAME" >/dev/null 2>&1 || true
}

app_is_running() {
  pgrep -x "$APP_NAME" >/dev/null || pgrep -x "$LEGACY_APP_BINARY_NAME" >/dev/null
}

strip_macos_metadata() {
  local target="$1"
  local item
  xattr -cr "$target" 2>/dev/null || true
  while IFS= read -r -d '' item; do
    xattr -c "$item" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
    xattr -d com.apple.provenance "$item" 2>/dev/null || true
  done < <(find "$target" -depth -print0 2>/dev/null)
  find "$target" \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true
}

verify_signed_bundle() {
  local target="$1"
  local tmp_parent
  local clean_target
  local status=0
  tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-verify.XXXXXX")"
  clean_target="$tmp_parent/$(basename "$target")"
  ditto --norsrc --noextattr "$target" "$clean_target" || status=$?
  if [[ "$status" -eq 0 ]]; then
    codesign --verify --deep --strict "$clean_target" || status=$?
  fi
  rm -rf "$tmp_parent"
  return "$status"
}

sign_app_bundle() {
  local target="$1"
  strip_macos_metadata "$target"
  codesign --force --sign - "$target"
  strip_macos_metadata "$target"
  verify_signed_bundle "$target"
}

build_bundle() {
  local stage_parent
  local stage_bundle
  local stage_contents
  local stage_macos
  local stage_resources
  local stage_binary
  local stage_info_plist
  local BUILD_MAIN

  rm -rf "$APP_BUNDLE"
  stage_parent="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-build.XXXXXX")"
  stage_bundle="$stage_parent/$APP_NAME.app"
  stage_contents="$stage_bundle/Contents"
  stage_macos="$stage_contents/MacOS"
  stage_resources="$stage_contents/Resources"
  stage_binary="$stage_macos/$APP_BINARY_NAME"
  stage_info_plist="$stage_contents/Info.plist"
  BUILD_MAIN="$stage_parent/main.swift"
  mkdir -p "$stage_macos" "$stage_resources" "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
  cp "$SOURCE_FILE" "$BUILD_MAIN"

  SWIFT_MODULE_CACHE_PATH="$SWIFT_MODULE_CACHE" \
  CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE" \
    swiftc "$BUILD_MAIN" -o "$stage_binary" -framework Cocoa -framework UserNotifications
  chmod +x "$stage_binary"
  cp "$ROOT_DIR/native/codex_status.py" "$stage_resources/codex_status.py"
  if [[ -f "$ROOT_DIR/native/assets/CodexGauge.icns" ]]; then
    cp "$ROOT_DIR/native/assets/CodexGauge.icns" "$stage_resources/CodexGauge.icns"
  fi

  cat >"$stage_info_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Codex Gauge</string>
  <key>CFBundleIconFile</key>
  <string>CodexGauge</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CodexGaugePythonPath</key>
  <string>/usr/bin/python3</string>
  <key>CodexGaugeUsagePath</key>
  <string>codex_status.py</string>
  <key>CodexGaugeReleaseURL</key>
  <string>$RELEASE_URL</string>
  <key>CodexGaugeUpdateTeamID</key>
  <string>$UPDATE_TEAM_ID</string>
</dict>
</plist>
PLIST

  sign_app_bundle "$stage_bundle"
  mkdir -p "$DIST_DIR"
  ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"
  strip_macos_metadata "$APP_BUNDLE"
  verify_signed_bundle "$APP_BUNDLE"
  rm -rf "$stage_parent"
}

open_app() {
  /usr/bin/open -na "$APP_BUNDLE"
}

launch_app_binary() {
  local app_path="$1"
  /usr/bin/open -na "$app_path"
}

install_launch_agent() {
  local app_path="$1"
  local agent_dir="$HOME/Library/LaunchAgents"
  mkdir -p "$agent_dir"
  cat >"$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-na</string>
    <string>$app_path</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  chmod 644 "$AGENT_PLIST"
}

install_app() {
  local target="/Applications/$APP_NAME.app"
  local legacy_target="/Applications/$LEGACY_APP_NAME.app"
  local user_target="$HOME/Applications/$APP_NAME.app"
  local tmp_target="/private/tmp/$APP_NAME.app"

  copy_verified_app() {
    local app_target="$1"
    mkdir -p "$(dirname "$app_target")"
    rm -rf "$app_target"
    ditto --norsrc --noextattr "$APP_BUNDLE" "$app_target" || return 1
    strip_macos_metadata "$app_target"
    verify_signed_bundle "$app_target"
  }

  rm -rf "$legacy_target" >/dev/null 2>&1 || true
  if copy_verified_app "$target"; then
    install_launch_agent "$target"
    launch_app_binary "$target"
    printf "Installed %s and enabled startup launch\n" "$target"
    return
  fi

  if copy_verified_app "$user_target"; then
    install_launch_agent "$user_target"
    launch_app_binary "$user_target"
    printf "Installed %s and enabled startup launch\n" "$user_target"
    return
  fi

  if copy_verified_app "$tmp_target"; then
    launch_app_binary "$tmp_target"
    printf "Installed temporary non-persistent app %s\n" "$tmp_target" >&2
    return
  fi

  printf "Could not install %s to /Applications, ~/Applications, or /private/tmp\n" "$APP_NAME" >&2
  return 1
}

build_bundle

case "$MODE" in
  --build-only|build-only)
    ;;
  run)
    stop_app
    open_app
    ;;
  --install|install)
    stop_app
    install_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    stop_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR process == \"$LEGACY_APP_BINARY_NAME\""
    ;;
  --telemetry|telemetry)
    stop_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_app
    open_app
    sleep 2
    app_is_running
    ;;
  *)
    echo "usage: $0 [run|--build-only|--install|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
