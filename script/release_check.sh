#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift script/generate_theme_state_previews.swift >/dev/null
python3 -m unittest discover -s tests -v
bash -n script/package_release.sh
bash -n script/soak_check.sh
./script/build_and_run.sh --build-only

TMP_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-release-check.XXXXXX")"
trap 'rm -rf "$TMP_PARENT"' EXIT

ditto --norsrc --noextattr native/dist/CodexGauge.app "$TMP_PARENT/CodexGauge.app"
codesign --verify --deep --strict "$TMP_PARENT/CodexGauge.app"

INFO_PLIST="$TMP_PARENT/CodexGauge.app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")" == "0.8.0" ]]
[[ "$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")" == "1" ]]
[[ "$(plutil -extract CodexGaugeUsagePath raw -o - "$INFO_PLIST")" == "codex_status.py" ]]
[[ "$(plutil -extract CodexGaugeReleaseURL raw -o - "$INFO_PLIST")" == "https://github.com/qingzhangeddie-byte/codex-gauge/releases" ]]

if git ls-files | grep -E '(^usage\.py$|^requirements\.txt$|^menubar/|^native/(build|dist)/|^\.venv/|^\.superpowers/|^docs/superpowers/|screenshot-.*\.png$)' >/dev/null; then
  printf "Public package contains blocked legacy or generated files.\n" >&2
  exit 1
fi

if git grep -n -I -E 'bustawind|/Users/|<your-fork-url>|support the author|Other projects by the author|browser-cookie3|--allow-browser-cookies|--allow-codex-auth|\.claude' -- \
  README.md README.zh-CN.md CHANGELOG.md SECURITY.md docs install.sh native .github >/dev/null; then
  printf "Public package contains blocked private or legacy text.\n" >&2
  exit 1
fi

sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-social-preview.png | grep -q "pixelWidth: 1280"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-social-preview.png | grep -q "pixelHeight: 640"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-menubar-live.png | grep -q "pixelWidth: 790"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-menubar-live.png | grep -q "pixelHeight: 96"

printf "Codex Gauge release check passed.\n"
