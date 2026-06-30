# Codex Gauge Privacy Notes

Codex Gauge is designed as a local macOS utility. It does not provide Codex access, does not bypass quota limits, and does not send your usage data to a third-party analytics service.

## Native Menu Bar App

The native menu bar app:

- reads live Codex quota through the local Codex app-server;
- runs the bundled helper with zero persistence, so live readings are not cached and Snapshot fallback is disabled in app mode;
- bundles its helper at `CodexGauge.app/Contents/Resources/codex_status.py`;
- performs one session-only update check after launch, and also performs a manual update check when you choose Check for Updates, contacting GitHub Releases to read the latest public release metadata;
- does not install a LaunchAgent, write support-folder logs, save preferences, write histories, cache live quota, or save report files;
- does not read browser cookies;
- does not read `~/.codex/auth.json`;
- does not scan your source code, Documents folder, browser profile, or Keychain.

The Codex app-server path can start or refresh the 5-hour Codex window because it talks to the same local Codex service that the Codex desktop app uses.

The updater is confirmation-based. The automatic check is session-only and does not write prompt decisions to app storage.

- Codex Gauge may remember a session-only skipped update version in memory for the current app session so it does not keep prompting for the same release.
- It writes no update history, skipped-version records, release notes, or downloaded update metadata to app storage.

If you choose Install Update, Codex Gauge saves the downloaded update zip to a temporary directory, verifies that it contains the Codex Gauge app bundle, replaces the installed app, and removes the temporary directory after relaunch. It keeps no updater cache or background update schedule.

Zero persistence is the default app mode. The app removes legacy Codex Gauge history, cache, report, log, and LaunchAgent files from earlier builds when it starts or when you choose Clear legacy data. It does not delete Codex auth/session data.

Codex Gauge does not ship a public broad usage CLI. The supported public artifact is the native menu bar app.
