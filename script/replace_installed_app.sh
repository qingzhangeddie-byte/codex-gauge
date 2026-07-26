#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexGauge"
LEGACY_APP_BINARY_NAME="${APP_NAME}-bin"
LEGACY_APP_NAME="AiLimitStatus"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/native/dist/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"
LEGACY_TARGET_APP="/Applications/$LEGACY_APP_NAME.app"
USER_TARGET_APP="$HOME/Applications/$APP_NAME.app"
TMP_TARGET_APP="/private/tmp/$APP_NAME.app"
AGENT_LABEL="app.codexgauge.menubar"
AGENT_PLIST="$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"

"$ROOT_DIR/script/build_and_run.sh" --build-only

launchctl_domain() {
  printf "gui/%s" "$(id -u)"
}

unload_launch_agent() {
  /bin/launchctl bootout "$(launchctl_domain)/$AGENT_LABEL" >/dev/null 2>&1 || true
}

unload_launch_agent
rm -f "$AGENT_PLIST" >/dev/null 2>&1 || true
rm -rf "$LEGACY_SUPPORT_DIR" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$LEGACY_APP_BINARY_NAME" >/dev/null 2>&1 || true
pkill -x "$LEGACY_APP_NAME" >/dev/null 2>&1 || true

verify_app_bundle() {
  local app_path="$1"
  [[ -x "$app_path/Contents/MacOS/$APP_NAME" ]] || return 1
  [[ -f "$app_path/Contents/Resources/codex_status.py" ]] || return 1
  [[ "$(plutil -extract CodexGaugeUsagePath raw -o - "$app_path/Contents/Info.plist" 2>/dev/null)" == "codex_status.py" ]] || return 1
  [[ "$(plutil -extract CFBundleShortVersionString raw -o - "$app_path/Contents/Info.plist" 2>/dev/null)" == "0.9.7" ]] || return 1
  [[ "$(plutil -extract CodexGaugeReleaseURL raw -o - "$app_path/Contents/Info.plist" 2>/dev/null)" == "https://github.com/qingzhangeddie-byte/codex-gauge/releases" ]] || return 1
  codesign --verify --deep --strict "$app_path" >/dev/null 2>&1 || return 1
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

replace_without_admin() {
  rm -rf "$LEGACY_TARGET_APP"
  rm -rf "$TARGET_APP"
  ditto --norsrc --noextattr "$SOURCE_APP" "$TARGET_APP"
}

replace_with_admin() {
/usr/bin/osascript \
  -e 'on run argv' \
  -e 'set sourceApp to item 1 of argv' \
  -e 'set targetApp to item 2 of argv' \
  -e 'set legacyTargetApp to item 3 of argv' \
  -e 'do shell script ("rm -rf " & quoted form of legacyTargetApp & " " & quoted form of targetApp & " && ditto --norsrc --noextattr " & quoted form of sourceApp & " " & quoted form of targetApp) with administrator privileges' \
  -e 'end run' \
  "$SOURCE_APP" "$TARGET_APP" "$LEGACY_TARGET_APP"
}

install_user_app() {
  mkdir -p "$(dirname "$USER_TARGET_APP")"
  rm -rf "$USER_TARGET_APP"
  if ! ditto --norsrc --noextattr "$SOURCE_APP" "$USER_TARGET_APP"; then
    return 1
  fi
  if ! verify_app_bundle "$USER_TARGET_APP"; then
    printf "User app did not contain the bundled Codex Gauge helper; aborting.\n" >&2
    return 1
  fi
  install_launch_agent "$USER_TARGET_APP"
  launch_app_binary "$USER_TARGET_APP"
  printf "Installed user app %s from %s and enabled startup launch\n" "$USER_TARGET_APP" "$SOURCE_APP"
}

install_tmp_app() {
  rm -rf "$TMP_TARGET_APP"
  if ! ditto --norsrc --noextattr "$SOURCE_APP" "$TMP_TARGET_APP"; then
    return 1
  fi
  if ! verify_app_bundle "$TMP_TARGET_APP"; then
    printf "Temporary app did not contain the bundled Codex Gauge helper; aborting.\n" >&2
    return 1
  fi
  launch_app_binary "$TMP_TARGET_APP"
  printf "Installed temporary non-persistent app %s from %s\n" "$TMP_TARGET_APP" "$SOURCE_APP"
}

if ! replace_without_admin; then
  printf "Direct replacement failed; asking macOS for administrator permission...\n" >&2
  if ! replace_with_admin; then
    printf "Administrator replacement failed; installing fixed app to user Applications instead...\n" >&2
    install_user_app || install_tmp_app
    exit 0
  fi
fi

if ! verify_app_bundle "$TARGET_APP"; then
  printf "Installed app did not contain the bundled Codex Gauge helper; aborting.\n" >&2
  exit 1
fi

install_launch_agent "$TARGET_APP"
launch_app_binary "$TARGET_APP"

printf "Replaced %s with %s and enabled startup launch\n" "$TARGET_APP" "$SOURCE_APP"
