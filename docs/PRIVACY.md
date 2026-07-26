# Codex Gauge Privacy Notes

Codex Gauge is designed as a local macOS utility. It does not provide Codex access, does not bypass quota limits, and does not send your usage data to a third-party analytics service.

## Native Menu Bar App

The native menu bar app:

- reads live Codex quota through the local Codex app-server using a live-only data path;
- does not cache live readings or create quota-history, report, or runtime-log files;
- does not read Codex session files or scan them for fallback quota values;
- bundles its helper at `CodexGauge.app/Contents/Resources/codex_status.py`;
- performs one session-only update check after launch, and also performs a manual update check when you choose Check for Updates, contacting GitHub Releases to read the latest public release metadata;
- installs only a user LaunchAgent for startup login and does not create an Application Support folder;
- does not read browser cookies;
- does not read `~/.codex/auth.json`;
- does not scan your source code, Documents folder, browser profile, or Keychain.

Reading live usage through the Codex app-server can start or refresh a quota window because Codex Gauge talks to the same local service that the ChatGPT app uses.

The updater is confirmation-based. The automatic check is session-only and does not write prompt decisions to app storage.

- Codex Gauge may remember a session-only skipped update version in memory for the current app session so it does not keep prompting for the same release.
- It writes no update history, skipped-version records, release notes, or downloaded update metadata to app storage.

If you choose Install Update, Codex Gauge saves the downloaded update zip to a temporary directory, verifies that it contains the Codex Gauge app bundle, replaces the installed app, and removes the temporary directory after relaunch. It keeps no updater cache or background update schedule.

Codex Gauge may keep `~/Library/LaunchAgents/app.codexgauge.menubar.plist` so it can open at login. Usage readings remain in memory only. During a short live failure, the running app may continue showing its last in-memory reading for up to 10 minutes while it labels the failure and retries; that value is not written to disk.

Codex Gauge does not ship a public broad usage CLI. The supported public artifact is the native menu bar app.
