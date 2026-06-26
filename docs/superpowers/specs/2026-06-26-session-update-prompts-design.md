# Session Update Prompts Design

## Goal

Codex Gauge should gently tell the user when a newer GitHub release is available without adding persistent storage or background power drain.

## User Choice

Use a session-only gentle update check:

- Check at most once per app run.
- Run only when the Mac is plugged in and Power Saver is inactive.
- If the user chooses not to update, do not prompt for that release again during the same app run.
- Manual **Check for Updates...** remains available and can always show the latest release information.

## Non-Goals

- Do not store dismissed update versions on disk.
- Do not add a daily schedule, updater cache, update history, or saved preference.
- Do not check while on battery.
- Do not auto-download or auto-install without confirmation.

## Architecture

Keep the existing updater path in `native/CodexGauge.swift` as the only release source. Add a small session-only automatic check coordinator beside the current manual updater state.

The coordinator owns only in-memory state:

- whether the automatic session check already ran;
- whether an automatic check is pending until external power returns;
- which release tag was dismissed during this app run;
- whether the current prompt is automatic or manual.

The existing `fetchLatestRelease`, `handleLatestRelease`, `showUpdatePrompt`, and `downloadAndInstallUpdate` functions stay responsible for GitHub metadata, release notes, confirmation, checksum validation, signature validation, install, and relaunch.

## Prompt Timing

On launch, schedule one delayed automatic check for about two minutes later. The delay keeps startup quiet and avoids competing with the first Codex refresh.

When the timer fires:

- skip if the app is on battery or Power Saver is active;
- mark the check as pending, then retry when the power-source notification says external power returned;
- skip if an update check or install is already running;
- perform one GitHub latest-release request when the Mac is plugged in.

Manual **Check for Updates...** should ignore these automatic-session guards because the user explicitly requested the check.

## Prompt Behavior

If the latest release is not newer than the installed app, update the menu summary quietly and show no automatic alert.

If a newer release exists:

- show the existing update prompt with release notes and actions;
- actions remain **Download & Install**, **Release Page**, and **Not Now**;
- when **Not Now** is selected during an automatic prompt, remember that release tag in memory and do not show it again during the same app run;
- when **Release Page** is selected during an automatic prompt, also treat that release as handled for the current app run;
- manual checks may show the prompt again even if the same tag was dismissed automatically.

## Power And Privacy

The automatic check is one network request per app run, only while plugged in. It must not wake the helper, run SSD temperature sampling, write local files, or create any cache. The app continues to advertise zero persistence accurately.

## Error Handling

Automatic failures should be quiet: update the in-memory menu summary if useful, but do not interrupt the user with a failure alert. Manual failures should keep the current alert behavior.

If the release is newer but has no downloadable CodexGauge zip asset, automatic mode should avoid opening the browser by itself. It may show a menu summary such as `Update available: vX` and let the user open the release page manually.

## Testing

Add static/unit coverage that checks:

- automatic update checks are session-only and delayed;
- automatic checks are skipped on battery and retried after external power returns;
- automatic update prompts are suppressed after **Not Now** or **Release Page** for that tag during the same app run;
- manual **Check for Updates...** still bypasses automatic suppression;
- automatic failures do not show blocking alerts;
- no `UserDefaults` or support-folder persistence is introduced for updater prompts.

Run the normal release checks after implementation:

- `python3 -m unittest discover -s tests -v`
- `./script/build_and_run.sh --build-only`
- `./script/release_check.sh`
