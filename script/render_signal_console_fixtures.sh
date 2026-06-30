#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BINARY="$ROOT_DIR/native/dist/CodexGauge.app/Contents/MacOS/CodexGauge"
OUTPUT_DIR="$ROOT_DIR/docs/design/app-rendered-signal-console"

"$ROOT_DIR/script/build_and_run.sh" --build-only

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
"$APP_BINARY" --render-signal-console-fixtures "$OUTPUT_DIR"
