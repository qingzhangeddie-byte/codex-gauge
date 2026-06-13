# Codex Gauge Signal Console UX Design

Date: 2026-06-13
Status: Design selected, awaiting implementation approval
Selected visual: `docs/design/codex-gauge-signal-console-v0.6.png`

## Goal

Codex Gauge should explain what the user is seeing when Codex live usage is unavailable. The menu bar must stop looking like a broken meter when Codex is closed, stalled, or unreachable. Instead, it should show an honest compact state and give the user the next action.

## Selected Direction

Use the **Signal Console** direction as the visual target. It keeps the app compact and native, but makes the dropdown feel like a small control center:

- Menu bar remains the primary surface.
- Dropdown explains data source, trend, doctor status, and diagnostics.
- Stalled/offline states use plain copy instead of fake percentages.
- Colors stay functional: teal for live, amber for cached/waiting, blue for snapshot, graphite for unavailable, red only for hard failure.

## Menu Bar States

The existing four-signal gauge remains the default live state.

States:

- **Live**: current compact two-row gauge with normal quota bars and reset mood lanes.
- **Last live**: same layout, amber source marker, slightly dimmed numbers, tooltip `Codex not reachable - showing last live`.
- **Snapshot**: same layout, blue source marker, cooler tint, tooltip `Codex closed - showing recent local snapshot`.
- **Unavailable / Stalled**: replace quota numbers with `--`, use grey rails, amber edge marker, and tooltip `Open Codex to refresh live usage`.

The unavailable state must not display old percentages. If there is no usable live, last-live, or fresh snapshot data, the menu bar should clearly read as waiting/offline.

## Dropdown Layout

The dropdown should be compact and grouped by purpose, with lightweight separators rather than card-heavy sections.

Order:

1. Header: plan name and current compact status summary.
2. Status explanation row:
   - `Live data is current`
   - `Showing last live cache`
   - `Open Codex to refresh live usage`
3. Quota rows for 5-hour and 7-day windows when values are available.
4. Reset rows for 5-hour and 7-day reset timing.
5. Trend row from recent local samples, e.g. `Trend: 5h -8% in 1h - 7d stable`.
6. Doctor summary row with the worst current check state and a `Run Check` action.
7. Actions: `Refresh Now`, `Setup Doctor`, `Preferences`, `Copy Diagnostics`, support folder, quit.

## Setup Doctor

Add a small native window or sheet named `Setup Doctor`. It should run checks on demand and show five rows:

- Codex app found
- Helper works
- Live data available
- LaunchAgent running
- Notifications permission

Each row should show a status dot:

- Green: good
- Amber: attention needed but recoverable
- Red: broken
- Grey: unknown or not checked

Each row gets one short fix hint. Example: `Open Codex, then Refresh Now`.

## Mini History

Store a bounded local history in Application Support. Keep only lightweight records:

```json
{"time":"...","source":"live","five_hour_left":73,"seven_day_left":89}
```

Rules:

- Keep at most 48 samples.
- Do not store prompts, responses, session paths, auth data, cookies, or logs.
- Use the history only for trend copy and future local reports.
- If history is missing or too sparse, show `Trend: collecting samples`.

## Reset Highlight

When the 5-hour quota crosses from low to refreshed, show a one-cycle understated highlight:

- Dropdown pill: `5h refreshed`
- Menu bar reset lane receives a brief warm pulse.
- No notification unless the user enabled notifications.

This should be subtle and bounded, similar to the existing mood animation.

## Preferences Polish

Refine Preferences into grouped native sections:

- Refresh: segmented control for `Adaptive`, `5 min`, `10 min`.
- Notifications: opt-in quota notifications and current permission state.
- Startup: Launch at login.
- Diagnostics: `Test Refresh`, `Setup Doctor`, `Copy Diagnostics`.

The window should stay small and utility-like. No landing-page styling.

## Safe Diagnostics

`Copy Diagnostics` should copy a plain-text report containing only:

- App version
- Helper path exists or missing
- Current data source
- Last refresh time
- Last error summary
- LaunchAgent state
- Notification permission state
- Refresh mode

It must exclude:

- Prompts
- Responses
- Browser cookies
- Auth files
- Session file contents
- Runtime logs by default
- Personal filesystem paths beyond standard app/support locations where possible

## Testing

Add static and behavioral tests for:

- Source-state copy for live, last-live, snapshot, unavailable.
- Unavailable state not drawing stale percentages.
- Setup Doctor check labels and safe status categories.
- History storage bounded to 48 samples and containing only allowed fields.
- Diagnostics export excluding blocked private/auth/log/session content.
- Preferences includes Test Refresh, Setup Doctor, and Copy Diagnostics.
- Release check still passes.

## Out Of Scope

- Exact billing report or dollar spend.
- Reading browser cookies.
- Reading `~/.codex/auth.json`.
- Uploading diagnostics anywhere.
- Big dashboard window.
- Push/tag/release automation.
