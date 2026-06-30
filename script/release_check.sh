#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift script/generate_theme_state_previews.swift >/dev/null
bash -n script/package_release.sh
bash -n script/soak_check.sh
bash -n script/render_signal_console_fixtures.sh
./script/build_and_run.sh --build-only
script/render_signal_console_fixtures.sh
swift script/generate_public_assets.swift >/dev/null
python3 -m unittest discover -s tests -v

TMP_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-release-check.XXXXXX")"
trap 'rm -rf "$TMP_PARENT"' EXIT

ditto --norsrc --noextattr native/dist/CodexGauge.app "$TMP_PARENT/CodexGauge.app"
codesign --verify --deep --strict "$TMP_PARENT/CodexGauge.app"

INFO_PLIST="$TMP_PARENT/CodexGauge.app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")" == "0.9.1" ]]
[[ "$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")" == "1" ]]
[[ "$(plutil -extract CodexGaugeUsagePath raw -o - "$INFO_PLIST")" == "codex_status.py" ]]
[[ "$(plutil -extract CodexGaugeReleaseURL raw -o - "$INFO_PLIST")" == "https://github.com/qingzhangeddie-byte/codex-gauge/releases" ]]
[[ -x "$TMP_PARENT/CodexGauge.app/Contents/Resources/ssd_temperature" ]]

if git ls-files | grep -E '(^usage\.py$|^requirements\.txt$|^menubar/|^native/(build|dist)/|^\.venv/|^\.superpowers/|screenshot-.*\.png$)' >/dev/null; then
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
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-github-hero.png | grep -q "pixelWidth: 1280"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-github-hero.png | grep -q "pixelHeight: 640"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-menubar-live.png | grep -q "pixelWidth: 790"
sips -g pixelWidth -g pixelHeight docs/assets/codex-gauge-menubar-live.png | grep -q "pixelHeight: 96"
for fixture in docs/design/app-rendered-signal-console/*.png; do
  sips -g pixelWidth -g pixelHeight "$fixture" | grep -q "pixelWidth: 1120"
  sips -g pixelWidth -g pixelHeight "$fixture" | grep -q "pixelHeight: 1120"
done

printf "Codex Gauge release check passed.\n"
