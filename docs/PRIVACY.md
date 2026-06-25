# Codex Gauge Privacy Notes

Codex Gauge is designed as a local macOS utility. It does not provide Codex access, does not bypass quota limits, and does not send your usage data to a third-party analytics service.

## Native Menu Bar App

The native menu bar app:

- reads live Codex quota through the local Codex app-server;
- falls back to bounded recent Codex session `rate_limits` metadata when app-server is unavailable from a background LaunchAgent, and labels that data as Snapshot;
- bundles its helper at `CodexGauge.app/Contents/Resources/codex_status.py`;
- optionally reads local SSD/NAND temperature from macOS IOReport when the sensor is exposed, showing only the temperature/status and no disk serials or file contents;
- samples CPU/RAM through macOS host statistics, storing only aggregated local CPU and RAM percentages with timestamps for the menu bar and 10-minute Signal Console movement view, with bounded history persisted at most once per minute;
- reads local battery percentage and power-source state through macOS power-source APIs for the menu bar battery glyph and automatic Power Saver;
- installs a per-user LaunchAgent at `~/Library/LaunchAgents/app.codexgauge.menubar.plist` so macOS keeps the menu bar process running;
- writes locally rotated runtime logs to `~/Library/Application Support/CodexGauge`;
- does not read browser cookies;
- does not read `~/.codex/auth.json`;
- does not store a process list, window titles, file paths, app names, or command lines for CPU/RAM display;
- does not scan your source code, Documents folder, browser profile, or Keychain.

The Codex app-server path can start or refresh the 5-hour Codex window because it talks to the same local Codex service that the Codex desktop app uses.

Battery state is local hardware telemetry only: current battery percentage, whether external power is connected, and whether Power Saver is active. Codex Gauge does not store battery history.

Each successful live reading is cached locally for short outages and can be reused for up to 30 minutes as **Last live**. The local snapshot fallback is read-only and bounded: it recursively checks recent Codex session `.jsonl` files, considers at most 80 recent files, reads at most the final 2 MB of each file, and extracts only `rate_limits` metadata. It only accepts snapshots captured within the last 15 minutes and keeps only windows with future reset times; for example, an expired 5-hour snapshot can be hidden while a still-valid 7-day snapshot remains visible as Snapshot.

Codex Gauge does not ship a public broad usage CLI. The supported public artifact is the native menu bar app.
