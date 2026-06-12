#!/usr/bin/env bash
# Codex Gauge native app installer
#
# This script intentionally installs from a local clone. It does not download
# a GitHub Release DMG and is not designed for network-piped shell execution.

set -euo pipefail

info() { printf "  \033[34m*\033[0m %s\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
die()  { printf "\n\033[31merror:\033[0m %s\n" "$*" >&2; exit 1; }

APP_DEST="/Applications/CodexGauge.app"
LEGACY_APP_DEST="/Applications/AiLimitStatus.app"

usage() {
  cat <<'USAGE'
Usage:
  bash install.sh

Builds and installs the native Codex Gauge menu-bar app from this local clone.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[[ "$(uname)" == "Darwin" ]] || die "macOS is required"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/native/CodexGauge.swift" && -f "$SCRIPT_DIR/native/codex_status.py" ]] || \
  die "Run this script from a local clone of Codex Gauge; do not pipe it from the network"

[[ -x "$SCRIPT_DIR/script/replace_installed_app.sh" ]] || die "native replacement script is missing"
if [[ -d "$LEGACY_APP_DEST" ]]; then
  info "Removing legacy app at $LEGACY_APP_DEST"
  rm -rf "$LEGACY_APP_DEST"
fi

info "Building and installing native menu-bar app to $APP_DEST"
"$SCRIPT_DIR/script/replace_installed_app.sh"
ok "Native menu-bar app installed"
printf "  Codex app-server live reads are enabled for real menu-bar usage; this can start or refresh the 5-hour window.\n"
