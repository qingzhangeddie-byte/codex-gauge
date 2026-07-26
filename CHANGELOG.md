# Changelog

## Unreleased

## v0.9.7 - 2026-07-26

- Fixed a weekly-only Codex response being mislabeled as a 5-hour window, which could show the wrong percentage and a nonsensical multi-day 5-hour countdown.
- Derived every quota label, percentage, and reset countdown from the live window duration returned by Codex instead of assuming fixed 5-hour and 7-day slots.
- Redesigned the menu bar and Signal Console around the windows that actually exist: one compact weekly row today, with automatic expansion if Codex returns additional windows later.
- Generalized low-quota and restored-quota notifications to the live window set.
- Refreshed the public screenshots, release wording, and regression coverage for the adaptive layout.

## v0.9.6 - 2026-07-11

- Restored live quota reads after the ChatGPT app-server began delaying `account/usage/read`; all three rate-limit verification requests now run concurrently instead of waiting behind that response.
- Added termination handling so forced refreshes clean up their app-server children instead of leaving orphaned local listeners.
- Increased the native refresh watchdog margin so the helper can finish its own fallback and cleanup paths.

## v0.9.5 - 2026-07-11

- Fixed the 5-hour gauge accepting a later stale sample when ChatGPT returned reset timestamps that drifted by several minutes within the same window.
- Made rollover detection scale with the reported quota-window duration, preserving genuine resets while rejecting intermittent stale usage snapshots.
- Added a regression fixture from the observed `67% used` versus stale `3% used` response pair.

## v0.9.4 - 2026-07-10

- Verified multiple live app-server readings before displaying quota, rejecting the intermittent stale `93% / 97%` snapshot while handling genuine reset-window rollovers correctly.
- Updated the live helper for the renamed ChatGPT host and primed usage before reading rate limits so 5-hour and 7-day percentages stay accurate.
- Removed Codex Gauge usage-history, cache, report, runtime-log, legacy-cleanup, and Codex session-file fallback paths; usage is now live-only and memory-only.
- Rebuilt Signal Console as a compact 380 x 272 quota panel with Morandi blue horizontal bars, reset countdowns, freshness, and essential actions only.
- Updated the open popover in place instead of recreating its view controller every second.
- Refreshed public screenshots, privacy notes, security notes, publishing guidance, and release checks for the live-only architecture.

## v0.9.3 - 2026-07-05

- Added a Codex Gauge logo and app icon built from the final horizontal menu bar meter language.
- Added DMG packaging alongside the existing zip package, with SHA-256 checksums for both release assets.
- Enabled startup launch through a user LaunchAgent while keeping quota cache, logs, histories, reports, and saved refresh preferences off.
- Updated install, privacy, publishing, and README copy to describe the startup-only local storage model accurately.

## v0.9.2 - 2026-07-03

- Minimized the menu bar glyph by removing the capsule remnants, divider, source stripe, state badge, and usage-bar cap dot.
- Refreshed public GitHub screenshots and README copy so generated images are clearly labeled as static sample values, not live account timing.
- Added a dedicated rendered GitHub hero image for the menu bar-focused product description.
- Removed stale unreferenced preview SVG mockups from the public docs assets.

## v0.9.1 - 2026-06-27

- Added a native battery signal and on-battery Power Saver mode that slows quota refresh and pauses background SSD, CPU, and RAM sampling.
- Switched the app to zero persistence mode: no saved preferences, LaunchAgent, runtime logs, local histories, caches, reports, or support-folder storage.
- Added session-only GitHub update checks that run only while plugged in, stay quiet on failure, and do not persist dismissed versions.
- Refreshed the Signal Console with the Porcelain Lab default theme, updated rendered previews, and clearer battery-mode surfaces.
- Hardened packaging, replacement, and update install checks around temporary files, checksums, and publisher validation.

## v0.9.0 - 2026-06-17

- Added a first-run setup surface that explains the local-only model and links to Codex and Setup Doctor.
- Restyled Preferences and Setup Doctor with the selected Signal Console theme.
- Added explicit Cache, Snapshot, and Open state badges to non-live menu bar states.
- Added an optional local SSD temperature readout in the menu bar and Setup Doctor when macOS exposes the IOReport sensor.
- Added local CPU/RAM percentages to the menu bar and Signal Console, with bounded 24-hour local metric history.
- Enlarged the menu bar CPU/RAM pod so the system metrics are readable at real menu-bar size.
- Changed reset countdown labels to use progressive units: minutes under an hour, hours under a day, and days plus hours for longer resets.
- Reduced CPU/RAM history disk churn: live samples still update every 5 seconds, but JSON persistence is throttled to once per minute and flushed on quit.

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
