#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ITERATIONS=12
INTERVAL=300
HELPER=""
OUT=""
PYTHON_BIN="/usr/bin/python3"
BATTERY_MODE=0

usage() {
  printf "usage: %s [--battery-mode] [--iterations N] [--interval SECONDS] [--helper PATH] [--out PATH]\n" "$0" >&2
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
    --battery-mode)
      BATTERY_MODE=1
      shift
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
  SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"
  mkdir -p "$SUPPORT_DIR"
  if [[ "$BATTERY_MODE" -eq 1 ]]; then
    OUT="$SUPPORT_DIR/CodexGauge-battery-soak-$(date -u +%Y%m%d-%H%M%S).jsonl"
  else
    OUT="$SUPPORT_DIR/CodexGauge-soak-$(date -u +%Y%m%d-%H%M%S).jsonl"
  fi
else
  mkdir -p "$(dirname "$OUT")"
fi

run_battery_mode_soak() {
  local runtime_log="$HOME/Library/Application Support/CodexGauge/CodexGauge-runtime.log"
  local observed_at
  local battery_text
  local log_bytes
  local ssd_parse_failures
  local codex_gauge_pids
  local helper_pids
  local codex_gauge_cpu
  local helper_process_count

  for ((i = 1; i <= ITERATIONS; i++)); do
    observed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    battery_text="$(pmset -g batt 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
    codex_gauge_pids="$(pgrep -f 'CodexGauge-bin|/Applications/CodexGauge.app/Contents/MacOS/CodexGauge' 2>/dev/null | paste -sd, - || true)"
    helper_pids="$(pgrep -f 'ssd_temperature|codex_status.py' 2>/dev/null | paste -sd, - || true)"
    helper_process_count=0
    if [[ -n "$helper_pids" ]]; then
      helper_process_count="$(printf "%s\n" "$helper_pids" | tr ',' '\n' | sed '/^$/d' | wc -l | tr -d ' ')"
    fi
    codex_gauge_cpu="$(ps -axo pid=,pcpu=,command= | awk '/CodexGauge-bin/ {sum += $2} END {printf "%.1f", sum + 0}')"
    if [[ -f "$runtime_log" ]]; then
      log_bytes="$(wc -c <"$runtime_log" | tr -d ' ')"
      ssd_parse_failures="$(grep -c "ssd temperature parse failed" "$runtime_log" || true)"
    else
      log_bytes=0
      ssd_parse_failures=0
    fi

    "$PYTHON_BIN" - "$observed_at" "$battery_text" "$codex_gauge_pids" "$helper_pids" "$helper_process_count" "$codex_gauge_cpu" "$log_bytes" "$ssd_parse_failures" >>"$OUT" <<'PY'
import json
import sys

observed_at, battery_text, codex_gauge_pids, helper_pids, helper_process_count, codex_gauge_cpu, log_bytes, ssd_parse_failures = sys.argv[1:9]
print(json.dumps({
    "observed_at": observed_at,
    "battery": battery_text,
    "codex_gauge_pids": [pid for pid in codex_gauge_pids.split(",") if pid],
    "helper_pids": [pid for pid in helper_pids.split(",") if pid],
    "helper_process_count": int(helper_process_count),
    "codex_gauge_cpu_percent": float(codex_gauge_cpu),
    "runtime_log_bytes": int(log_bytes),
    "ssd_parse_failures": int(ssd_parse_failures),
}, sort_keys=True, separators=(",", ":")))
PY

    if [[ "$i" -lt "$ITERATIONS" ]]; then
      sleep "$INTERVAL"
    fi
  done

  "$PYTHON_BIN" - "$OUT" <<'PY'
import json
import sys

path = sys.argv[1]
samples = []
with open(path, "r", encoding="utf-8") as handle:
    samples = [json.loads(line) for line in handle if line.strip()]

first = samples[0] if samples else {}
last = samples[-1] if samples else {}
summary = {
    "samples": len(samples),
    "path": path,
    "first_battery": first.get("battery", ""),
    "last_battery": last.get("battery", ""),
    "max_codex_gauge_cpu_percent": max((sample.get("codex_gauge_cpu_percent", 0.0) for sample in samples), default=0.0),
    "max_helper_process_count": max((sample.get("helper_process_count", 0) for sample in samples), default=0),
    "runtime_log_bytes_delta": int(last.get("runtime_log_bytes", 0)) - int(first.get("runtime_log_bytes", 0)),
    "ssd_parse_failures_before": int(first.get("ssd_parse_failures", 0)),
    "ssd_parse_failures_after": int(last.get("ssd_parse_failures", 0)),
}
print(json.dumps(summary, indent=2, sort_keys=True))
PY
}

if [[ "$BATTERY_MODE" -eq 1 ]]; then
  run_battery_mode_soak
  exit 0
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
  if CODEX_GAUGE_SUPPORT_DIR="$(dirname "$OUT")" "$PYTHON_BIN" "$HELPER" --status-json >"$stdout_file" 2>"$stderr_file"; then
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
