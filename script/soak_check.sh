#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ITERATIONS=12
INTERVAL=300
HELPER=""
OUT=""
PYTHON_BIN="/usr/bin/python3"

usage() {
  printf "usage: %s [--iterations N] [--interval SECONDS] [--helper PATH] [--out PATH]\n" "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="${2:?missing value for --iterations}"
      shift 2
      ;;
    --interval)
      INTERVAL="${2:?missing value for --interval}"
      shift 2
      ;;
    --helper)
      HELPER="${2:?missing value for --helper}"
      shift 2
      ;;
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$OUT" ]]; then
  OUTPUT_DIR="${TMPDIR:-/tmp}"
  OUT="$OUTPUT_DIR/CodexGauge-soak-$(date -u +%Y%m%d-%H%M%S).jsonl"
else
  mkdir -p "$(dirname "$OUT")"
fi

if [[ -z "$HELPER" ]]; then
  if [[ -f "/Applications/CodexGauge.app/Contents/Resources/codex_status.py" ]]; then
    HELPER="/Applications/CodexGauge.app/Contents/Resources/codex_status.py"
  else
    HELPER="$ROOT_DIR/native/codex_status.py"
  fi
fi

if [[ ! -f "$HELPER" ]]; then
  printf "Missing helper: %s\n" "$HELPER" >&2
  exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/codex-gauge-soak.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

for ((i = 1; i <= ITERATIONS; i++)); do
  stdout_file="$tmpdir/stdout-$i.json"
  stderr_file="$tmpdir/stderr-$i.txt"
  observed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    if CODEX_GAUGE_SUPPORT_DIR="$tmpdir" CODEX_GAUGE_NO_STORAGE=1 "$PYTHON_BIN" "$HELPER" --status-json >"$stdout_file" 2>"$stderr_file"; then
    "$PYTHON_BIN" - "$observed_at" "$stdout_file" >>"$OUT" <<'PY'
import json
import sys

observed_at, path = sys.argv[1:3]
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["observed_at"] = observed_at
print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
PY
  else
    "$PYTHON_BIN" - "$observed_at" "$stderr_file" >>"$OUT" <<'PY'
import json
import sys

observed_at, path = sys.argv[1:3]
with open(path, "r", encoding="utf-8", errors="replace") as handle:
    error = handle.read().strip()
print(json.dumps({
    "observed_at": observed_at,
    "codex": {"ok": False, "source": "command_error", "error": error},
}, sort_keys=True, separators=(",", ":")))
PY
  fi

  if [[ "$i" -lt "$ITERATIONS" ]]; then
    sleep "$INTERVAL"
  fi
done

"$PYTHON_BIN" - "$OUT" <<'PY'
import collections
import json
import sys

path = sys.argv[1]
source_counts = collections.Counter()
unavailable_count = 0
samples = 0

with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        if not line.strip():
            continue
        samples += 1
        payload = json.loads(line)
        codex = payload.get("codex", {})
        source_counts[codex.get("source") or "unknown"] += 1
        if not codex.get("ok"):
            unavailable_count += 1

summary = {
    "samples": samples,
    "source_counts": dict(sorted(source_counts.items())),
    "unavailable_count": unavailable_count,
    "path": path,
}
print(json.dumps(summary, indent=2, sort_keys=True))
PY
