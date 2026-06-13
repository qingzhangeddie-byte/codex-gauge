#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BINARY="$ROOT_DIR/native/dist/CodexGauge.app/Contents/MacOS/CodexGauge-bin"
OUTPUT_DIR="$ROOT_DIR/docs/design/app-rendered-signal-console"

if [[ ! -x "$APP_BINARY" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --build-only
fi

"$APP_BINARY" --render-signal-console-fixtures "$OUTPUT_DIR"
