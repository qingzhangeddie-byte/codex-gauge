# Battery Power Saver Design

## Goal

Add a native battery signal and an aggressive on-battery Power Saver mode to Codex Gauge.

The feature should answer two questions without turning Codex Gauge into a general power monitor:

- How much battery is left?
- Is Codex Gauge reducing its own background activity because the Mac is unplugged?

## Approved Direction

Use a native **Battery Signal + Power Saver Policy**:

- Read battery and power-source state through macOS native power-source APIs.
- Show a small familiar battery-shaped glyph in the menu bar.
- Auto-enable Power Saver whenever the Mac is running on battery.
- Keep plugged-in behavior unchanged.
- Make on-battery behavior materially quieter, while keeping quota refresh useful.

## Non-Goals

- Do not use a copied Apple asset or system image. Draw the battery glyph with native AppKit primitives.
- Do not add a full battery history graph in this version.
- Do not store battery history in a local file for this version.
- Do not remove existing quota, reset, SSD temperature, CPU, or RAM signals.
- Do not read browser cookies, Codex auth files, Keychain, prompts, responses, process lists, app names, window titles, or file paths.
- Do not shell out to expensive polling commands such as `pmset` for routine battery state.

## Menu Bar Design

The menu bar remains quota-first.

Add a compact battery glyph near the existing local system signals:

- Rounded battery outline.
- Small terminal nub on the right.
- Fill level proportional to charge.
- Compact percentage text when space allows.
- Muted outline when plugged in.
- Mint fill when healthy on battery.
- Amber below 30 percent.
- Coral below 15 percent.

When Power Saver is active, the menu bar should make that state visible without becoming noisy. Prefer a subtle visual treatment on the battery glyph and tooltip text over a large always-visible label. If the final layout has room, a tiny `Saver` or `PS` marker may appear next to the glyph.

The status tooltip should include battery and Power Saver state, for example:

- `Battery 74%, Power Saver active`
- `Battery 100%, plugged in`
- `No battery detected`

## Signal Console Design

Signal Console should expose the state more explicitly than the menu bar:

- Show current battery percentage.
- Show plugged-in versus on-battery state.
- Show whether Power Saver is active.
- Show the current quota refresh cadence chosen by the Power Saver policy.
- Keep CPU/RAM and SSD temperature as local context, but make their on-battery sampling behavior clear through compact labels rather than explanatory body copy.

The existing Movement section remains focused on quota, SSD temperature, CPU, and RAM. Battery does not need a graph in this version.

## Power Saver Behavior

Power Saver auto-enables whenever a battery exists and the Mac is not connected to external power.

Plugged in:

- Keep the current refresh behavior.
- Adaptive mode remains `5m` normal, `3m` low quota, `2m` critical, and `1m` after transient errors.
- Existing fixed refresh preferences continue to work as they do today.
- SSD temperature and CPU/RAM background sampling keep their current intervals.

On battery:

- Use aggressive quota refresh intervals:
  - `20m` when quota is healthy.
  - `10m` when quota is low.
  - `5m` when quota is critical or after a transient refresh error.
- Manual `Refresh Now` still runs immediately.
- Pause background SSD temperature and CPU/RAM history sampling.
- While Signal Console is open, temporarily sample SSD temperature and CPU/RAM every `10s`.
- Stop the temporary hardware sampler when Signal Console closes.
- Continue sampling battery state at a low cadence so the menu bar stays honest.

If the user manually chooses `5 minutes` or `10 minutes` refresh while on battery, Power Saver still caps background refresh to the on-battery cadence. The user can always run `Refresh Now` for an immediate live read.

## Data Model

Add an in-memory battery status model with:

- `percent: Int?`
- `isPluggedIn: Bool?`
- `isCharging: Bool?`
- `hasBattery: Bool`
- `powerSaverActive: Bool`
- `source: String`
- `error: String?`

Battery status is not persisted in v1. It can be included in diagnostics and current UI state, but it should not create a new history file.

Power Saver policy should be isolated from rendering:

- A battery reader returns battery status.
- A policy helper decides whether Power Saver is active.
- Refresh scheduling asks the policy for the next interval.
- Hardware samplers ask the policy whether background sampling is allowed.
- UI renderers receive plain model values and do not decide policy.

## Failure Handling

If battery status cannot be read:

- Hide the menu bar battery glyph on desktop Macs with no battery.
- Show a muted unavailable battery state if a battery is expected but reading fails.
- Do not enable Power Saver solely because battery reading failed.
- Keep Codex quota refresh working.
- Include the failure summary in Copy Diagnostics.

If the Mac switches power source:

- Update the battery glyph promptly.
- Recompute the next quota refresh interval.
- Pause or resume background SSD/CPU/RAM sampling according to the new state.
- Avoid duplicate timers after repeated plug/unplug transitions.

If Signal Console is open on battery:

- Start the temporary 10-second hardware sampler.
- Refresh the visible console model as samples arrive.
- Stop the sampler when the console closes.

## Preferences

Keep the default behavior simple: Power Saver activates automatically on battery.

Do not add a new preference in v1. The feature should be automatic, visible, and reversible by plugging the Mac back into power.

If a later version needs user control, add a single checkbox named `Power Saver on battery`, default it to enabled, and make disabling it restore plugged-in refresh and hardware sampling behavior even while unplugged.


## Privacy and Storage

Battery state is local hardware telemetry only. It contains charge percentage and power-source state, not user content.

The feature must not add:

- Battery history files.
- Network calls.
- Auth reads.
- Browser-cookie reads.
- Process inspection.
- App/window/file path collection.

Diagnostics may include current battery percentage, plugged-in state, and Power Saver state.

## Testing Requirements

Tests should verify:

- Battery reader uses native macOS APIs rather than recurring shell commands.
- Battery status model exists and supports unavailable, plugged-in, charging, and on-battery states.
- Menu bar rendering includes a battery-shaped glyph without removing quota, reset, SSD temperature, CPU, or RAM signals.
- Power Saver activates on battery and not when plugged in.
- Plugged-in refresh behavior remains unchanged.
- On-battery refresh uses `20m`, `10m`, and `5m` intervals.
- Manual Refresh bypasses waiting and runs immediately.
- Background SSD temperature and CPU/RAM sampling pause on battery.
- Signal Console open state enables temporary `10s` hardware sampling on battery.
- Closing Signal Console stops the temporary sampler.
- Copy Diagnostics and Setup Doctor include current battery and Power Saver state.
- README and privacy docs describe battery state as local hardware telemetry and avoid implying battery history storage.
