# Changelog

## v0.4.0 - 2026-06-12

- Repositioned the project as Codex Gauge, a Codex-only macOS menu bar quota gauge.
- Shows 5-hour and 7-day quota with reset countdown lanes.
- Uses a local Codex app-server live data path with bounded Snapshot fallback.
- Does not read browser cookies, `~/.codex/auth.json`, Keychain, or unrelated project folders.
- Replaced legacy CLI surfaces with a native app bundle and bundled helper.
- Added LaunchAgent persistence, adaptive refresh, runtime log rotation, and public release hygiene checks.
