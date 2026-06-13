# Signal Console Command Center Design

Date: 2026-06-13

## Goal

Evolve the selected **B - Cleaner command center** direction into a focused v0.7 update for Codex Gauge. The popover should stay compact and premium, while adding three practical improvements:

- clearer trend context;
- a local usage report action;
- a calmer lower half with a compact health strip instead of a tall Doctor block.

This keeps Codex Gauge aligned with macOS menu bar behavior: quick status at a glance, transient popover interaction, and deeper details only when the user asks for them.

## Non-Goals

- Do not build a full dashboard.
- Do not estimate dollar spend.
- Do not read prompts, responses, cookies, `~/.codex/auth.json`, or full session contents.
- Do not add cloud sync, telemetry, or analytics.
- Do not remove Setup Doctor or safe diagnostics; make them quieter.

## UX Direction

The current top half of the Signal Console is strong and should remain recognizable:

1. Header: `Codex Gauge - Signal Console`, source pill, info icon.
2. Hero card: 5h and 7d rails, reset lanes, and Live / Last live / Snapshot / Codex closed state.
3. Status, Quota, Reset, and Trend sections.

The redesign focuses below and around Trend:

1. **Trend Detail**
   - Keep the visible row compact:
     - `5-hour trend    -14% this window`
     - `7-day trend     -2% in 24h`
   - Add one muted context line below Trend:
     - `Based on 18 live samples from 13:25 to 18:28`
   - If samples are sparse:
     - `Collecting enough samples for a useful trend`
   - If the source is Snapshot / Last live:
     - `Trend uses local history; latest source is Snapshot`

2. **Usage Report Entry Point**
   - Add a quiet row named `Usage Report`.
   - Primary action: `Generate`.
   - Output: a local plain-text or Markdown report copied to clipboard and optionally saved in Application Support.
   - Initial report should summarize quota movement, not token spend:
     - first and latest 5-hour quota in the report window;
     - first and latest 7-day quota in the report window;
     - largest observed drop;
     - source mix: Live / Last live / Snapshot;
     - note that it is an estimate from quota snapshots, not billing or token accounting.

3. **Compact Health Strip**
   - Replace the tall five-row Doctor section in the popover with a one-line health strip:
     - `Health  4 OK  1 optional`
   - Use small colored dots for Codex app, helper, live data, LaunchAgent, notifications.
   - Keep `Run Check...` as the action.
   - The full Setup Doctor window remains available for details.

4. **Diagnostics**
   - Keep `Copy Safe Diagnostics...` below the health strip.
   - Keep the copy clear:
     - `Includes version, source, last error, LaunchAgent state.`
   - Do not include logs, prompts, session content, auth files, browser state, or personal paths.

## Layout

The popover should keep roughly the same width and height. The lower area becomes denser but calmer:

```text
Trend
  5-hour trend      -14% this window       sparkline   -14
  7-day trend        -2% in 24h            sparkline    -2
  Based on 18 live samples from 13:25 to 18:28

Report
  Usage Report       24h quota summary                  Generate

Health
  Codex app  Helper  Live  Login  Alerts                Run Check...

Diagnostics
  Copy Safe Diagnostics...                              Copy
```

The design should avoid nested cards. Use separators, small dots, and one filled button for the current primary row action.

## Data Model

Reuse `HistorySample`:

```swift
time: String
source: String
fiveHourLeft: Int?
sevenDayLeft: Int?
```

Add lightweight computed summaries only:

- `TrendContext`
  - `sampleCount`
  - `liveSampleCount`
  - `firstTime`
  - `lastTime`
  - `latestSource`
  - `summaryText`

- `UsageReportSummary`
  - `windowLabel`
  - `firstFiveHourLeft`
  - `latestFiveHourLeft`
  - `firstSevenDayLeft`
  - `latestSevenDayLeft`
  - `largestFiveHourDrop`
  - `largestSevenDayDrop`
  - `sourceCounts`
  - `generatedAt`

All summaries derive from already-bounded local history. No new private data source is introduced.

## Actions

### Generate Usage Report

Add `@objc private func generateUsageReport()`:

1. Read bounded history.
2. Filter to the last 24 hours by default.
3. Build a Markdown string with:
   - title: `Codex Gauge Usage Report`;
   - generated time;
   - visible current source;
   - 5-hour quota movement;
   - 7-day quota movement;
   - source mix;
   - limitations.
4. Copy it to the pasteboard.
5. Optionally write it to Application Support as `CodexGauge-usage-report.md`.
6. Show a short native alert:
   - success: `Usage report copied`
   - sparse data: `Not enough history yet`

### Run Check

Keep existing Setup Doctor behavior. The compact strip calls the same `openSetupDoctor` action.

### Copy Diagnostics

Keep existing safe diagnostics behavior.

## Error Handling

- If there are fewer than two usable history points, report generation should not invent data.
- If only one quota dimension is available, the report should include that dimension and mark the other as unavailable.
- If the app is showing non-live data, the report should label the latest source.
- If writing the report file fails, still copy to clipboard and show that the file save failed in the alert.
- If clipboard copy fails, show an alert and do not claim success.

## Testing

Use static and behavioral tests before implementation:

1. Signal Console source contains `Usage Report`, `Generate`, `Health`, and `Based on`.
2. Popover no longer renders five full Doctor rows inline; it renders a compact health strip and keeps `Run Check...`.
3. `generateUsageReport` exists and uses only `HistorySample`, bounded history, and safe status metadata.
4. Report text includes an explicit limitation that it estimates quota movement, not token spend or billing.
5. Safe diagnostics exclusions remain unchanged.
6. Existing release check still passes.
7. Native build succeeds.
8. Installed app screenshot shows no text overlap.

## Decision

Implement the first report as **24-hour quota movement only**. Token and dollar estimates should wait until there is a separate, explicit data-quality design, because local quota snapshots are not the same as billable token accounting.

## References

- Apple Human Interface Guidelines: The menu bar - https://developer.apple.com/design/Human-Interface-Guidelines/the-menu-bar
- Apple Human Interface Guidelines: Popovers - https://developer.apple.com/design/human-interface-guidelines/popovers
