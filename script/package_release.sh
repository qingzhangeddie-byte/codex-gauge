#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="CodexGauge"
APP_VERSION="$(awk -F'"' '/^APP_VERSION=/{print $2; exit}' "$ROOT_DIR/script/build_and_run.sh")"
RELEASE_DIR="$ROOT_DIR/native/dist/release"
PACKAGE_NAME="CodexGauge-$APP_VERSION"
PACKAGE_DIR="$RELEASE_DIR/$PACKAGE_NAME"
ZIP_PATH="$RELEASE_DIR/CodexGauge-$APP_VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

./script/build_and_run.sh --build-only

rm -rf "$PACKAGE_DIR" "$ZIP_PATH" "$CHECKSUM_PATH"
mkdir -p "$PACKAGE_DIR"
ditto --norsrc --noextattr "$ROOT_DIR/native/dist/$APP_NAME.app" "$PACKAGE_DIR/$APP_NAME.app"

installer="$PACKAGE_DIR/Install Codex Gauge.command"
cat >"$installer" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexGauge"
LEGACY_APP_NAME="AiLimitStatus"
AGENT_LABEL="app.codexgauge.menubar"
AGENT_PLIST="$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$PACKAGE_DIR/$APP_NAME.app"

launchctl_domain() {
  printf "gui/%s" "$(id -u)"
}

unload_launch_agent() {
  /bin/launchctl bootout "$(launchctl_domain)/$AGENT_LABEL" >/dev/null 2>&1 || true
}

launch_app_binary() {
  local app_path="$1"
  /usr/bin/open -na "$app_path"
}

copy_app() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  ditto --norsrc --noextattr "$APP_SRC" "$target"
  codesign --verify --deep --strict "$target" >/dev/null
}

if [[ ! -d "$APP_SRC" ]]; then
  printf "Missing %s next to this installer.\n" "$APP_SRC" >&2
  exit 1
fi

unload_launch_agent
rm -f "$AGENT_PLIST" >/dev/null 2>&1 || true
rm -rf "$LEGACY_SUPPORT_DIR" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$APP_NAME-bin" >/dev/null 2>&1 || true
rm -rf "/Applications/AiLimitStatus.app" "$HOME/Applications/AiLimitStatus.app" >/dev/null 2>&1 || true

if copy_app "/Applications/$APP_NAME.app"; then
  launch_app_binary "/Applications/$APP_NAME.app"
  printf "Installed /Applications/%s.app\n" "$APP_NAME"
  exit 0
fi

if copy_app "$HOME/Applications/$APP_NAME.app"; then
  launch_app_binary "$HOME/Applications/$APP_NAME.app"
  printf "Installed %s/Applications/%s.app\n" "$HOME" "$APP_NAME"
  exit 0
fi

printf "Could not install %s to /Applications or ~/Applications.\n" "$APP_NAME" >&2
exit 1
INSTALLER
chmod +x "$installer"

cat >"$PACKAGE_DIR/README-INSTALL.txt" <<README
Codex Gauge $APP_VERSION

This package contains only CodexGauge.app and an install command.
It does not include logs, local support data, browser cookies, or source checkout files.

Install:
1. Open "Install Codex Gauge.command".
2. If macOS blocks the app, this build is ad-hoc signed and not notarized yet.
   Until Developer ID notarization is configured, build locally or allow it from System Settings.

After install:
- Codex Gauge appears in the macOS menu bar.
- Preferences lets you choose Adaptive, 5 minutes, or 10 minutes refresh.
- Notifications are opt-in.
- Zero persistence mode keeps no LaunchAgent, support-folder logs, caches, histories, reports, or saved preferences.
README

(
  cd "$RELEASE_DIR"
  COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
  shasum -a 256 "$ZIP_PATH" >"$CHECKSUM_PATH"
)

printf "Release package: %s\n" "$ZIP_PATH"
printf "Checksum: %s\n" "$CHECKSUM_PATH"
