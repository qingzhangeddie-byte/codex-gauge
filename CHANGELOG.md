# Changelog

## v0.4.1 - 2026-06-13

- Prevented stale fallback quota from being shown as current usage.
- Added a bounded Last live cache for short Codex app-server outages.
- Added menu bar source markers for Live, Last live, and Snapshot states.
- Tightened Snapshot freshness checks to require recent capture timestamps.
- Updated release hygiene so private untracked marketing drafts do not affect public package checks.

## v0.4.0 - 2026-06-12

- Repositioned the project as Codex Gauge, a Codex-only macOS menu bar quota gauge.
- Shows 5-hour and 7-day quota with reset countdown lanes.
- Uses a local Codex app-server live data path with bounded Snapshot fallback.
- Does not read browser cookies, `~/.codex/auth.json`, Keychain, or unrelated project folders.
- Replaced legacy CLI surfaces with a native app bundle and bundled helper.
- Added LaunchAgent persistence, adaptive refresh, runtime log rotation, and public release hygiene checks.
