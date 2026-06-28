# Codex Gauge Porcelain Circuit Blue Ceramic Redesign

Date: 2026-06-28
Status: Approved for specification
Selected visual: `docs/design/porcelain-circuit-blue-ceramic-final-battery-blue.png`

## Goal

Redesign Codex Gauge as one coherent native macOS utility system. The app should feel clear, modern, and purpose-built rather than like separate menu, popover, and utility-window pieces.

The redesign covers:

- Menu bar gauge
- Signal Console popover
- Battery mode and refresh cadence states
- Preferences
- Setup Doctor
- Update prompt
- Zero-persistence and diagnostics copy

The app's job remains narrow: show Codex quota, live/source state, reset timing, battery-aware refresh behavior, and local health checks without storing usage data.

## Current Context

The existing app already has the important behavior:

- A Retina-rendered menu bar gauge for 5-hour and 7-day quota.
- Battery status and power-saving refresh intervals.
- Signal Console popover with quota, movement, live summary, health, and actions.
- Setup Doctor and Preferences utility windows.
- Manual and optional automatic update checks.
- Zero persistence for usage history, cache, snapshots, reports, and app logs.

The main issue is visual hierarchy. Battery mode, refresh timing, update state, and privacy behavior are present but not always obvious. The redesigned system should make those states legible without increasing background work.

## Visual Direction

Use **Porcelain Circuit - Blue Ceramic**.

This is a light native utility UI with ceramic-white surfaces, cool blue-gray lines, etched circuit-trace dividers, precise instrument rows, and compact monospaced values. It should look like a small macOS instrument panel, not a web dashboard or landing page.

The one aesthetic risk is the etched circuit trace motif. It is allowed because it is specific to the product: Codex Gauge is reading local signals and turning them into a small status instrument. The motif must be restrained and structural, used as separators and empty-space texture, not decoration pasted everywhere.

## Design Tokens

Colors:

- Porcelain background: `#F6FBFF`
- Ceramic frost surface: `#E8F3FA`
- Deep ink text: `#10233A`
- Live teal: `#1DBBB7`
- Ceramic blue system and battery: `#376C8F`
- Reset amber: `#E2A635`
- Low or critical coral: `#E7625C`
- Ceramic line: `#A8BFD0`

Typography:

- Primary UI: native macOS system font, semibold for headings and controls.
- Data values: monospaced digits for percentages, reset times, countdowns, and battery percentages.
- Labels: compact native UI labels, medium weight, sentence case unless the platform control naturally uses title case.
- Body copy: short native utility copy, never marketing copy.

Geometry:

- Utility panels use 12-18 px corner radius depending on size.
- Inner rows use 10-14 px radius.
- Buttons use native-feeling low radius with clear hover/pressed/focus states.
- Avoid nested card-heavy layouts. Use rows, ribbons, dividers, etched traces, and grouped utility sections.

Motion:

- Motion is understated and bounded.
- Reset refresh pulse is one cycle only.
- Refresh countdown can update text, but no continuous visual animation is required.
- Respect reduced motion.

## Color Semantics

Each color has one job:

- Teal means live quota or healthy signal.
- Ceramic blue means system layer, battery, update metadata, or secondary signal.
- Amber means reset countdown or refresh timing.
- Coral means low quota, low battery, critical state, or negative movement.
- Ink means primary text and neutral battery outline when needed.
- Line color means structure only.

Battery rule:

- Normal battery uses a ceramic-blue shell and ceramic-blue fill.
- On battery or power saver mode still uses a ceramic-blue battery icon.
- The Battery mode strip is blue-tinted, not amber.
- `Refresh 60m` or the current slowed cadence is shown clearly in the Battery mode strip.
- Coral appears only when battery is below the low or critical threshold.
- Amber is not used for the battery icon. It is reserved for reset or refresh timing.

## Menu Bar Gauge

The menu bar is the glance surface. It should stay compact and high contrast.

Required content:

- 5h quota label and rail.
- 7d quota label and rail.
- Reset timing marker or text.
- Battery icon using the selected blue battery rule.
- Refresh cadence only when it matters, such as power saver or low battery mode.

Layout:

```text
[5h 80% rail] | [7d 79% rail] | [R 4:58] | [blue battery icon]
```

Behavior:

- Do not show hardware extras when power saver is active unless they are already sampled without extra work.
- On battery, prioritize quota, refresh cadence, and battery status.
- If live data is unavailable, show honest unavailable rails and a clear tooltip.
- The menu bar should not display personal paths, logs, or diagnostic text.

## Signal Console Popover

The popover is the detailed control surface.

Order:

1. Header with app name, live/source controls, and next refresh.
2. Dual quota instrument for 5h and 7d.
3. Battery mode strip when battery or power saver state matters.
4. Movement and usage summary, if available without stored history.
5. Health ribbon with local checks.
6. Bottom command row.

Layout:

```text
Codex Gauge - Signal Console         [Live] [Source]
[Live signal] [Live 2m ago]                         [next 4:58]

[5h quota instrument + reset lane]
[7d quota instrument + reset lane]

[blue battery icon] Battery mode - Refresh 60m          >

[Movement]                       [Usage summary]

[Health: Code Menu Store Last SSD CPU RAM] [Run Check]

[Open Codex] [Refresh Now] [Preferences] [Quit]
```

Copy rules:

- Use `Battery mode`, not `Battery Saver`, when the primary meaning is "the app changed refresh cadence while on battery."
- Use `Power Saver active` only as secondary detail.
- Use `Copy summary` only for live-only clipboard summaries.
- Use `Copy Diagnostics` for diagnostics.
- Do not use `Share Report` because the app should not imply saved report files.

## Preferences

Preferences should become a real utility window, not a plain collection of controls.

Structure:

- Left navigation or grouped sections may be used if it fits the native window size.
- Sections: General, Appearance, Signals, Updates, Battery, Storage, Advanced, About.
- If a sidebar is too much for the current AppKit implementation, use stacked grouped sections with the same visual tokens.

Required controls:

- Refresh cadence: Adaptive, Every 5 minutes, Every 10 minutes, plus any existing app-specific options.
- Live signal source display.
- Battery saver threshold.
- Extend refresh interval on battery.
- Check for updates automatically.
- Check Now.
- Zero persistence status.
- Reset to Defaults.
- Done.

Power guidance:

- Copy should make the tradeoff clear: shorter intervals use more power.
- On battery, the UI should explain the effective slowed cadence.

Storage guidance:

- Zero persistence section states: no stored cache, snapshot, usage history, report, or app log.
- If the app must remember a non-usage preference such as skipped update version, label it separately as an app preference, not usage data.

## Setup Doctor

Setup Doctor should be privacy-safe and action-oriented.

Rows:

- Live signal source
- Network
- Permissions
- Disk access
- Battery access
- System integrity
- Helper availability
- Notifications, if enabled by existing behavior

Rules:

- Do not show personal filesystem paths.
- Do not show prompts, responses, cookies, auth files, runtime logs, or session contents.
- Use short fix hints, such as `Open Codex, then Refresh Now`.
- Status dots use teal for OK, amber for attention, coral for broken, blue for informational, gray for unknown.

Actions:

- Run Full Diagnostics
- Copy Diagnostics

Diagnostics remain clipboard-only unless the existing app explicitly needs an alert. No report file should be created.

## Update Prompt

The update prompt must provide update information without becoming annoying.

Prompt content:

- Current version and latest version.
- Release title and publish date when available.
- Compact release notes preview.
- Download size when available.
- Security verification status when available.

Actions:

- Skip this version
- Remind me later
- Install Update
- Check Now from Preferences
- Release Page from menu

Rules:

- If the user skips a version, do not prompt again for that version.
- Manual Check Now can still show the skipped version because the user asked for it.
- Remind me later should wait until the next reasonable update check, not loop in the same session.
- On battery power, automatic checks should avoid unnecessary network work and should not interrupt unless the update is already known or user-initiated.
- Release notes must be plain text. Do not render remote HTML inside the app.

Persistence note:

- Skipped update version and update preferences are app preferences, not usage data. They may be stored only if the app already has a preferences mechanism. They must not include quota values, prompts, responses, logs, auth data, cookies, or local project paths.

## Zero Persistence

The redesign must preserve the current privacy promise.

No usage data storage:

- No quota history file.
- No last-live cache.
- No local snapshot fallback.
- No generated usage report file.
- No app log file by default.
- No prompt, response, browser cookie, Keychain, auth, or session content reads.

Allowed:

- In-memory samples for current UI while the app is running.
- Clipboard output when the user explicitly copies a live summary or diagnostics.
- App preferences required for UI behavior, such as refresh mode, theme, skipped update version, and notification setting.

Any persistence in implementation must be reviewed against this distinction.

## Power Behavior

The redesign should reduce work while preserving the useful display.

On battery:

- Hide or suppress nonessential hardware signals if they require active sampling.
- Keep quota and battery information visible.
- Show effective refresh cadence prominently.
- Avoid no-op redraws when battery state has not changed.
- Coalesce timers where possible.
- Do not run automatic update network checks during low or critical battery unless the user requests it.

On charge:

- Preserve current display richness.
- Keep SSD, CPU, RAM, and health information available if existing sampling allows it.
- Do not reduce the usefulness of the charged-state display.

## Component Boundaries

Implementation should keep visual and behavior responsibilities separated:

- Theme tokens and semantic colors in one focused area.
- Menu bar gauge drawing in focused drawing helpers.
- Signal Console drawing and button placement in focused helpers.
- Preferences and Setup Doctor utility views using shared utility styles.
- Update prompt copy and actions kept separate from release-fetching logic.
- Power policy remains independent from drawing.

Do not turn `CodexGauge.swift` into a larger unstructured file if avoidable. When touching existing large areas, extract only focused helpers that directly serve this redesign.

## Error Handling

- Live data unavailable: show honest empty rails and explain how to refresh.
- Sensor unavailable: show unavailable state, not stale sensor values.
- Battery access unavailable: hide battery details or show unknown state without warning color.
- Update check fails: show a short safe error summary and keep existing app state.
- Download verification fails: do not install; show why in plain language.
- Preferences conflicts: explain the effective refresh cadence rather than showing contradictory controls.

## Testing And Verification

Tests should cover:

- Battery color semantics: normal and power-saver battery are blue, low/critical battery is coral, reset remains amber.
- Battery mode copy and refresh cadence text.
- On-battery UI hides extra hardware signals without hiding quota and battery.
- Update prompt actions, including skipped version behavior.
- Setup Doctor does not expose personal paths.
- Diagnostics copy excludes prompts, responses, cookies, auth files, logs, session contents, and project paths.
- Zero-persistence assertions remain true.
- Menu bar rendering remains Retina scale-aware and stable.
- Existing release check passes.

Visual verification:

- Compare implemented UI against `docs/design/porcelain-circuit-blue-ceramic-final-battery-blue.png`.
- Capture menu bar, Signal Console, Preferences, Setup Doctor, and update prompt.
- Check at least normal, on-battery/power-saver, low quota, unavailable live data, and update-available states.
- Verify text fits within native controls at current and narrow window sizes.

## Out Of Scope

- Big dashboard window.
- Usage history persistence.
- Saved report files.
- Cloud sync.
- Reading browser cookies or Codex auth files.
- Exact billing or cost reports.
- Replacing the native macOS app with a web app.
