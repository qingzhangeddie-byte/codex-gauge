# CPU and RAM Signal Design

## Goal

Add local CPU and RAM usage percentages to Codex Gauge without turning the app into a generic system monitor.

The feature should answer one practical question: while watching Codex quota, is the Mac also under obvious system load?

## Approved Direction

Use a compact **System Strip**:

- Menu bar keeps the current quota rows, reset lanes, reset countdowns, and SSD temperature chip.
- Menu bar adds compact monospaced CPU and RAM percentages as a tiny system strip.
- Signal Console adds CPU and RAM to the existing local status surface instead of creating another large card.
- CPU and RAM sampling runs every 5 seconds.
- Dropdown graphing shows the last 10 minutes.
- Local CPU/RAM history is retained for 24 hours and then pruned.

## Visual Behavior

### Menu Bar

The menu bar remains quota-first. CPU and RAM are secondary system signals.

Use very short labels:

- `C18` for CPU 18 percent
- `R62` for RAM 62 percent

Use the existing compact menu bar palette. Color should follow local pressure:

- Mint below normal pressure
- Amber at elevated pressure
- Coral at high pressure
- Muted when unavailable

The system strip must not remove:

- 5-hour quota row
- 7-day quota row
- percentages
- reset mood lanes
- reset countdown text
- SSD temperature chip

### Signal Console

Keep Movement focused on trend-like information:

- quota movement
- SSD temperature graph
- CPU and RAM mini readouts with small last-10-minute lines

Use labels that are understandable at a glance:

- `CPU`
- `RAM`
- current percentages
- `last 10m`

Do not add explanatory body text inside the app. The UI should rely on compact labels and visual hierarchy.

## Data Behavior

Sampling:

- CPU and RAM sample every 5 seconds.
- Sampling must be local-only.
- Sampling must not read browser cookies, Codex auth files, prompts, responses, or unrelated user data.
- Sampling must avoid expensive subprocess loops when a native system API is enough.

Storage:

- Store bounded system metric samples in `~/Library/Application Support/CodexGauge`.
- Retain at most 24 hours of samples.
- Use a dedicated file separate from quota history and temperature history.
- Clear local data removes CPU/RAM metric history.

Fallback:

- If CPU or RAM cannot be sampled, display `--` in the menu bar and Signal Console.
- A failed sample should not break quota rendering.

## Implementation Notes

The existing app is a native Swift/AppKit single-file app. Follow its current patterns:

- Add a `SystemMetricSample` codable model.
- Add a timer in `CodexGaugeApp`.
- Add bounded storage similar to temperature history.
- Add fields to `SignalConsoleModel`.
- Draw the compact menu bar strip inside the existing status image.
- Regenerate app-rendered Signal Console fixtures and public README images.

## Testing Requirements

Tests must verify:

- CPU/RAM sampler exists and runs every 5 seconds.
- CPU/RAM retention is 24 hours and bounded.
- Clear local data removes metric history.
- Menu bar still keeps quota, reset, and SSD temp signals.
- Signal Console exposes CPU and RAM current values and history.
- Public README explains local CPU/RAM metrics without implying private data collection.
