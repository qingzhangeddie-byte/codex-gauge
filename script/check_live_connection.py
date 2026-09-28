#!/usr/bin/env python3
"""Opt-in integration check against the installed Codex app-server."""

import argparse
import importlib.util
import json
import pathlib
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--helper", type=pathlib.Path,
                        default=pathlib.Path("/Applications/CodexGauge.app/Contents/Resources/codex_status.py"))
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("codex_gauge_live_check", args.helper)
    if spec is None or spec.loader is None:
        raise RuntimeError("Codex Gauge helper was not found")
    # Do not add bytecode files to the signed app bundle.
    sys.dont_write_bytecode = True
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper._install_termination_handlers()
    cli = helper.find_codex_cli()
    if not cli:
        raise RuntimeError("No installed Codex executable was found")
    version = subprocess.run([cli, "--version"], env=helper.codex_subprocess_env(),
                             capture_output=True, text=True, check=True, timeout=10).stdout.strip()
    snapshot = helper.build_status_snapshot()
    status = snapshot["codex"]
    if not status.get("ok") or status.get("source") != "live":
        raise RuntimeError(status.get("error") or "No live reading")
    windows = status.get("quota_windows") or []
    if not windows or any(type(window.get("percent_left")) not in (int, float)
                          or not 0 <= window["percent_left"] <= 100 for window in windows):
        raise RuntimeError("Invalid quota percentages")
    print(json.dumps({"ok": True, "cli_version": version, "title": snapshot["title"],
                      "quota_windows": windows, "source": status["source"]}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Live integration check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
