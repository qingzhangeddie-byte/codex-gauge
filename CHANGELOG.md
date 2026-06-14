# Changelog

## Unreleased

- Added a first-run setup surface that explains the local-only model and links to Codex and Setup Doctor.
- Restyled Preferences and Setup Doctor with the selected Signal Console theme.
- Added explicit Cache, Snapshot, and Open state badges to non-live menu bar states.

## v0.8.0 - 2026-06-13

- Added selectable Signal Console themes: Paper Console by default, Signal Dark, and Mono Graphite.
- Made the local 24-hour usage report visible directly inside the Signal Console.
- Added a compact Today summary to the report card and copied report.
- Added live-age wording for Live, Last live, and Snapshot states so stale data is obvious.
- Changed usage report generation to copy-only; Codex Gauge no longer saves a report Markdown file.
- Added Clear local data for Codex Gauge history, Last live cache, legacy report files, and logs without touching Codex auth/session data.
- Updated app version metadata and release instructions for the theme release.

## v0.7.0 - 2026-06-13

- Added a real next-refresh countdown in the Signal Console that follows the actual scheduled refresh timer.
- Made quota movement labels sharper with signed 5-hour and 7-day percentage deltas.
- Clarified the Codex-closed state with an explicit no-live-quota marker in the popover.
- Refreshed public release metadata for the next GitHub package.

## v0.6.0 - 2026-06-13

- Implemented the Signal Console UX direction for clearer Live, Last live, Snapshot, and unavailable states.
- Reworked the live menu bar gauge with segmented signal rails and a source rail so the new UI is visible even when Codex data is healthy.
- Replaced the plain dropdown menu with a custom dark Signal Console popover showing status, quota, reset timing, trend, doctor checks, diagnostics, and actions.
- Added an explicit unavailable menu bar state that says to open Codex instead of showing stale percentages.
- Added source explanations, bounded local trend history, Setup Doctor, and safe diagnostics copy.
- Changed trend windows from a vague sample count to 5-hour current-window movement and 7-day 24-hour movement.
- Added a compact Health strip and local 24-hour quota movement report in the Signal Console.
- Polished Preferences with Test Refresh, Setup Doctor, and Copy Diagnostics controls.

## v0.5.0 - 2026-06-13

- Added a native Preferences window for refresh cadence, opt-in quota notifications, and LaunchAgent login control.
- Added opt-in user notifications for low 5-hour quota, refreshed 5-hour quota, and prolonged non-live data.
- Added `script/package_release.sh` to build a public zip with checksum, install command, and no runtime logs or local support data.
- Added `script/soak_check.sh` for long-running JSONL reliability sampling across Live, Last live, Snapshot, and unavailable states.
- Linked the native app with `UserNotifications` and kept fallback/source labels visible.

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
