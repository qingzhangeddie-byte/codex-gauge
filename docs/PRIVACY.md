# Codex Gauge Privacy Notes

Codex Gauge is designed as a local macOS utility. It does not provide Codex access, does not bypass quota limits, and does not send your usage data to a third-party analytics service.

## Native Menu Bar App

The native menu bar app:

- reads live Codex quota through the local Codex app-server;
- falls back to bounded recent Codex session `rate_limits` metadata when app-server is unavailable from a background LaunchAgent, and labels that data as Snapshot;
- bundles its helper at `CodexGauge.app/Contents/Resources/codex_status.py`;
- installs a per-user LaunchAgent at `~/Library/LaunchAgents/app.codexgauge.menubar.plist` so macOS keeps the menu bar process running;
- writes locally rotated runtime logs to `~/Library/Application Support/CodexGauge`;
- does not read browser cookies;
- does not read `~/.codex/auth.json`;
- does not scan your source code, Documents folder, browser profile, or Keychain.

The Codex app-server path can start or refresh the 5-hour Codex window because it talks to the same local Codex service that the Codex desktop app uses.

The local snapshot fallback is read-only and bounded: it recursively checks recent Codex session `.jsonl` files, considers at most 80 recent files, reads at most the final 2 MB of each file, and extracts only `rate_limits` metadata. It keeps only windows with future reset times; for example, an expired 5-hour snapshot can be hidden while a still-valid 7-day snapshot remains visible as Snapshot.

Codex Gauge does not ship a public broad usage CLI. The supported public artifact is the native menu bar app.
