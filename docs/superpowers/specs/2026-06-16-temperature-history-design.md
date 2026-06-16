# Codex Gauge Temperature History Design

## Goal

Add a live SSD temperature history view that feels native to Codex Gauge's Signal Console without making the menu bar heavier.

The menu bar keeps the current temperature chip, such as `44°`, but the quota and reset rails are shortened so the whole status image is more compact. The dropdown adds a smooth temperature curve inside the existing Movement section.

## Non-Goals

- Do not add a temperature graph to the menu bar.
- Do not remove any current menu bar information: 5-hour quota, 7-day quota, percentages, reset lanes, reset countdown text, and SSD temperature remain visible.
- Do not read browser cookies, Codex auth files, Keychain, or any user content.
- Do not store unbounded sensor history.

## Menu Bar Design

The menu bar status image should be redesigned as a tighter instrument strip:

- Keep the `5h` and `7d` row labels.
- Shorten quota rails to roughly half their current perceived width.
- Keep percentage labels next to the shortened rails.
- Keep the current SSD temperature chip visually similar to the existing chip.
- Keep reset mood lanes and countdown labels, but compress their spacing.
- Preserve non-live states such as Open Codex, Snapshot, and Last live.

The target is a shorter, denser status item that still scans quickly.

## Dropdown Design

The existing Movement card becomes the home for the new temperature history:

- Keep quota movement in the card.
- Add a second lane titled `SSD temp`.
- Show a smooth curve for the last 60 seconds of samples.
- Show the current temperature on the right, for example `44°`.
- Use the existing thermal palette:
  - Mint or teal for normal temperatures.
  - Amber for warm temperatures.
  - Coral for hot temperatures.
- Add a subtle filled area under the curve to make it feel polished, not technical.
- If no samples are available, show a muted empty curve and `SSD temp unavailable`.

The curve should be visually calm. It can smooth short-term jitter, but the numeric current temperature stays raw and honest.

## Data Flow

Codex Gauge already has a local SSD temperature helper. The app should add a lightweight temperature sampler:

1. Read SSD temperature from the existing helper every 1 second while the app is running.
2. Store samples in a small rolling in-memory buffer.
3. Keep enough samples for the last 60 seconds in the live Movement curve.
4. Persist bounded temperature samples in a dedicated local temperature-history file so future reporting can reuse the same data without changing the runtime model.
5. The existing Clear local data action removes the temperature-history file together with quota history, cache, and logs.

The sampler must not block Codex usage refreshes. If the helper fails, record an unavailable sample or skip the sample, then keep the UI responsive.

## Failure Handling

If the SSD helper is unavailable:

- The menu bar temperature chip shows `--°` only when the menu-bar SSD setting is enabled.
- The Movement card shows `SSD temp unavailable`.
- Setup Doctor and diagnostics continue to report the sensor state.
- Codex quota data continues updating normally.

If a single temperature read fails after previous reads succeeded:

- Keep the latest valid temperature in the chip until it becomes stale.
- Render the curve from available valid samples.
- Avoid flashing or aggressive warning states for short gaps.

## Preferences

The existing `Show SSD temperature in menu bar` preference controls only the menu bar chip. It does not disable the sampler or dropdown diagnostics, because the dropdown can still be useful when the user opens it intentionally.

## Privacy and Storage

Temperature samples are local hardware telemetry only. They do not identify files, apps, documents, browsing activity, Codex prompts, or account data.

History must remain bounded. The implementation should avoid large logs or indefinite sensor streams.

## Testing Plan

Add tests for:

- A 1-second temperature sampling timer exists.
- Temperature history is bounded.
- Clear local data removes stored temperature history.
- The Signal Console model exposes temperature history for the Movement section.
- The Movement section contains `SSD temp`, current temperature text, and unavailable copy.
- The compact menu bar still includes quota rows, percentage text, reset lanes, reset countdowns, and the existing temperature chip.
- Release checks still cover the SSD helper and public-safe documentation.

## Open Implementation Notes

The native app is currently concentrated in `native/CodexGauge.swift`. The implementation should stay scoped, but temperature-history sampling and rendering should be separated into small helper methods or structs so the file does not become harder to reason about.
