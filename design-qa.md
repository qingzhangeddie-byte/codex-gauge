# Adaptive Quota Design QA

## Target

- Selected visual: `docs/design/adaptive-v0.9.7/selected-reference.png`
- Reference raster: 1619 x 971 px
- Direction: one live weekly quota row, compact horizontal meter, moving reset countdown, and automatic expansion only when the service returns another window
- Palette anchors: meter fill `#8696B9`; charcoal meter well at device white `0.08`

## Implementation

- Live menu bar capture: `docs/design/adaptive-v0.9.7/live-menubar.png`
- Native Signal Console render: `docs/design/app-rendered-signal-console/blue-ceramic-live.png`
- Menu bar crop: 520 x 80 px from a 2x Retina capture
- Signal Console: 780 x 420 px for a 390 x 210 pt native panel at 2x
- Live state checked: `7d 94%`, reset `6d23h`
- App-rendered fixture state: `7d 82%`, reset `6d23h`, next refresh `4:58`

## Comparisons

- Focused menu bar comparison: `docs/design/adaptive-v0.9.7/menubar-comparison.png`
- Full popover comparison: `docs/design/adaptive-v0.9.7/popover-comparison.png`
- The left side of each comparison is the selected reference; the right side is the implementation.

## Findings

- The implementation shows exactly one row for the one weekly window currently returned by Codex. It does not reserve space for or invent a removed 5-hour limit.
- The live menu item deliberately uses the smaller font and meter density of the adjacent CPU monitor instead of the oversized conceptual menu bar type.
- Label, percentage, meter, and reset countdown preserve the reference order and remain legible against the live light menu bar.
- The Signal Console keeps the reference hierarchy while removing decorative vertical space, producing a tighter 390 x 210 pt panel.
- The healthy meter uses the sampled CPU fill `#8696B9`, a charcoal empty well, one-pixel inset, and restrained corners in both menu bar and popover.
- Refresh, Preferences, and Quit use native SF Symbols with tooltips and accessibility labels.
- No overlap, clipping, empty second row, blurred raster status item, or fixed-width placeholder was found.

## Iteration History

1. The first adaptive render used a pale rounded popover rail. Replaced it with the selected charcoal system-meter well and exact Morandi blue fill.
2. The original icon encoded `5h` and `7d`. Replaced it with a timeless single adaptive meter asset and regenerated every icon size.
3. The first v0.9.7 package inherited the local Swift compiler's macOS 28 deployment target, so LaunchServices rejected it on macOS 27. The build now targets macOS 13 explicitly, and the release check verifies the binary load command as well as the plist.
4. Regenerated native fixtures, README visuals, GitHub hero, social preview, and menu bar sample after the final meter correction.

## Final Result

passed
