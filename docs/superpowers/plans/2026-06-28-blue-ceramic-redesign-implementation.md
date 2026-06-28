# Blue Ceramic Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Porcelain Circuit - Blue Ceramic redesign across the Codex Gauge menu bar, Signal Console, utility windows, updater prompt, tests, and rendered visual assets.

**Architecture:** Keep the app native AppKit and preserve zero persistence. Add focused visual helpers inside the existing native app first, then extract only if implementation becomes too tangled. The highest-risk file is `native/CodexGauge.swift`, so run one worker task at a time for that file and review between tasks.

**Tech Stack:** Swift/AppKit menu bar app, Python `unittest` static contract tests, Swift fixture render scripts, shell release/build scripts.

---

## Scope Check

The approved spec covers one coherent redesign system, not unrelated features. It is broad, but each task below is independently testable:

- Task 1 updates tests and contracts.
- Task 2 updates Blue Ceramic theme tokens and menu bar battery semantics.
- Task 3 updates Signal Console layout, copy, and battery mode hierarchy.
- Task 4 updates Preferences, Setup Doctor, and update prompt behavior.
- Task 5 regenerates visual fixtures and public assets.
- Task 6 performs build, install, screenshot, visual comparison, and release verification.

Subagent execution should be sequential for tasks that edit `native/CodexGauge.swift`. Parallelize only read-only review or independent asset generation after code has settled.

## File Structure

- Modify `native/CodexGauge.swift`: theme tokens, menu bar drawing, Signal Console layout/drawing, utility windows, update prompt, preview cases.
- Modify `native/CodexGaugePowerPolicy.swift`: only if Task 4 finds a missing explicit power rule; otherwise leave it alone.
- Modify `tests/test_signal_console_ux.py`: visual contract tests for Blue Ceramic tokens, Signal Console hierarchy, and rendered fixtures.
- Modify `tests/test_native_hardening.py`: privacy, zero-persistence, power, battery semantics, and updater prompt tests.
- Modify `tests/test_public_release_hygiene.py`: fixture and public asset expectations.
- Modify `docs/PRIVACY.md`, `README.md`, and `README.zh-CN.md`: only for updater skip wording and renamed visible surfaces.
- Modify `script/generate_theme_state_previews.swift`: Blue Ceramic theme-state QA preview.
- Modify `script/generate_public_assets.swift`: public screenshot copy and selected fixture paths.
- Generated output:
  - `docs/design/codex-gauge-theme-state-fixtures.png`
  - `docs/design/app-rendered-signal-console/*.png`
  - `docs/assets/codex-gauge-signal-console.png`
  - `docs/assets/codex-gauge-social-preview.png`
  - `docs/assets/codex-gauge-menubar-live.png` if menu bar rendering changes affect the generated asset.

## Subagent Ownership

Use one worker per task. Tell every worker:

- You are not alone in the codebase.
- Do not revert edits made by others.
- Keep your write scope to the files named in your task.
- If a needed change falls outside your files, stop and report it.
- List every file you changed in your final response.

Recommended worker order:

1. Contracts worker: Task 1.
2. Menu bar/theme worker: Task 2.
3. Signal Console worker: Task 3.
4. Utility/updater worker: Task 4.
5. Assets worker: Task 5.
6. Verification worker or main agent: Task 6.

---

### Task 1: Update Tests For The Blue Ceramic Contract

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `tests/test_native_hardening.py`
- Modify: `tests/test_public_release_hygiene.py`

- [ ] **Step 1: Add failing Signal Console visual contract tests**

Append these tests to `tests/test_signal_console_ux.py` near the existing theme and compact-layout tests:

```python
    def test_blue_ceramic_is_default_redesign_theme(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            'blueCeramicThemeKey = "blueCeramic"',
            "private var sessionSignalConsoleThemeKey = blueCeramicThemeKey",
            "private func blueCeramicTheme() -> SignalConsoleTheme",
            'name: "Blue Ceramic"',
            "panelBackground: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0)",
            "mintAccent: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96)",
            "amberAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96)",
            "coralAccent: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96)",
            "blueAccent: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96)",
        ]:
            self.assertIn(token, source)

        self.assertIn('"Blue Ceramic"', source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertNotIn("UserDefaults.standard", source)

    def test_battery_uses_blue_semantics_not_amber_in_power_saver(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private func batterySignalColor(_ status: BatteryStatus?) -> NSColor",
            "private func batterySoftFillColor(_ status: BatteryStatus?) -> NSColor",
            "return blueAccent",
            "return theme.blueAccent",
            "Battery mode",
            "Refresh \\(minutes)m",
        ]:
            self.assertIn(token, source)

        battery_color_body = self._swift_function_body(source, "private func batterySignalColor(_ status: BatteryStatus?) -> NSColor")
        self.assertIn("if let percent = status.percent, percent < 15", battery_color_body)
        self.assertIn("return coralAccent", battery_color_body)
        self.assertIn("return blueAccent", battery_color_body)
        self.assertNotIn("return amberAccent", battery_color_body)

        menu_battery_body = self._swift_function_body(source, "private func batteryMenuBarColor(_ status: BatteryStatus?, palette: GaugePalette) -> NSColor")
        self.assertIn("return currentSignalConsoleTheme().blueAccent", menu_battery_body)
        self.assertNotIn("return warningQuotaColor", menu_battery_body)

    def test_signal_console_has_dedicated_battery_mode_strip(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "var batteryModeStripRect: NSRect",
            "drawBatteryModeStrip()",
            "drawSignalHeroCard()",
            '"Battery mode"',
            '"Power Saver active"',
            "model.refreshCadenceText",
            "blueSoft",
        ]:
            self.assertIn(token, source)

        panel_body = self._swift_function_body(source, "private func drawSignalConsolePanel()")
        self.assertLess(panel_body.index("drawSignalHeroCard()"), panel_body.index("drawBatteryModeStrip()"))
        self.assertLess(panel_body.index("drawBatteryModeStrip()"), panel_body.index("drawTrendSection()"))
```

- [ ] **Step 2: Add failing hardening tests for updater skip and privacy-safe utility copy**

Append these tests to `tests/test_native_hardening.py` near the updater and zero-persistence tests:

```python
    def test_updater_prompt_uses_skip_later_install_without_persistent_history(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        privacy = pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8")
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for token in [
            "automaticUpdateSkippedTagName",
            "Skip this version",
            "Remind me later",
            "Install Update",
            "mode == .automatic, automaticUpdateSkippedTagName == release.tagName",
            "automaticUpdateSkippedTagName = release.tagName",
        ]:
            self.assertIn(token, source)

        self.assertNotIn("UserDefaults.standard", source)
        self.assertNotIn("dismissed-version record", privacy)
        self.assertIn("session-only skipped update version", privacy)
        self.assertIn("Skip this version", readme)

    def test_utility_windows_use_blue_ceramic_privacy_safe_copy(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for label in [
            "Blue Ceramic",
            "Battery mode",
            "Zero persistence",
            "No stored cache or snapshot",
            "Run Full Diagnostics",
            "Copy Diagnostics",
            "Check Now",
            "Done",
        ]:
            self.assertIn(f'"{label}"', source)

        for blocked in [
            '"LOCAL_HOME_PATH/',
            '"Share Report"',
            '"Open Support Folder"',
            '"saved preferences, histories, caches, reports, or logs"',
        ]:
            self.assertNotIn(blocked, source)
```

- [ ] **Step 3: Update visual asset tests to expect Blue Ceramic fixtures**

In `tests/test_public_release_hygiene.py`, update the fixture expectations in `test_theme_state_visual_fixture_generator_covers_all_states` and `test_actual_app_rendered_signal_console_fixtures_exist`.

Use these replacement fragments:

```python
        for phrase in [
            "Blue Ceramic",
            "Signal Dark",
            "Mono Graphite",
            "Live",
            "Codex closed",
            "Live only",
            "Low quota",
            "Battery mode",
            "docs/design/codex-gauge-theme-state-fixtures.png",
        ]:
            self.assertIn(phrase, script_text)
```

```python
        expected = [
            "blue-ceramic-live.png",
            "blue-ceramic-codex-closed.png",
            "blue-ceramic-last-live.png",
            "blue-ceramic-low-quota.png",
            "blue-ceramic-plugged-in-full.png",
            "blue-ceramic-battery-mode.png",
            "signal-dark-live.png",
            "signal-dark-codex-closed.png",
            "signal-dark-last-live.png",
            "signal-dark-low-quota.png",
            "signal-dark-plugged-in-full.png",
            "signal-dark-battery-mode.png",
            "mono-graphite-live.png",
            "mono-graphite-codex-closed.png",
            "mono-graphite-last-live.png",
            "mono-graphite-low-quota.png",
            "mono-graphite-plugged-in-full.png",
            "mono-graphite-battery-mode.png",
        ]
```

- [ ] **Step 4: Run tests to verify they fail for the expected missing contracts**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux tests.test_native_hardening tests.test_public_release_hygiene -v
```

Expected: FAIL. The failure messages should mention missing Blue Ceramic theme, missing battery color helper, missing dedicated battery mode strip, missing updater skip labels, and missing Blue Ceramic fixtures.

- [ ] **Step 5: Commit the failing contracts**

Run:

```bash
git add tests/test_signal_console_ux.py tests/test_native_hardening.py tests/test_public_release_hygiene.py
git commit -m "test: codify blue ceramic redesign contract"
```

Expected: commit succeeds.

---

### Task 2: Implement Blue Ceramic Theme Tokens And Menu Bar Battery Semantics

**Files:**
- Modify: `native/CodexGauge.swift`
- Test: `tests/test_signal_console_ux.py`
- Test: `tests/test_native_hardening.py`

- [ ] **Step 1: Add the Blue Ceramic theme key and default**

Modify the theme-key block in `native/CodexGauge.swift`:

```swift
private let blueCeramicThemeKey = "blueCeramic"
private let porcelainLabThemeKey = "porcelainLab"
private let paperConsoleThemeKey = "paperConsole"
private let signalDarkThemeKey = "signalDark"
private let monoGraphiteThemeKey = "monoGraphite"
```

Modify the default session theme:

```swift
private var sessionSignalConsoleThemeKey = blueCeramicThemeKey
```

Modify `registerDefaultPreferences()`:

```swift
private func registerDefaultPreferences() {
    sessionSignalConsoleThemeKey = blueCeramicThemeKey
    sessionRefreshMode = adaptiveRefreshMode
    sessionNotificationsEnabled = false
    sessionShowSSDTemperatureInMenuBar = true
}
```

- [ ] **Step 2: Add the complete Blue Ceramic theme function**

Add this function near `porcelainLabTheme()`:

```swift
private func blueCeramicTheme() -> SignalConsoleTheme {
    SignalConsoleTheme(
        key: blueCeramicThemeKey,
        name: "Blue Ceramic",
        appearance: .aqua,
        material: .popover,
        panelBackground: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0),
        panelStrongBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
        panelSoftBackground: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.070),
        panelBorder: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.88),
        textPrimary: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.98),
        textSecondary: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.92),
        textMuted: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.82),
        buttonPrimaryText: NSColor.white,
        secondaryButtonBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 0.84),
        commandButtonBackground: NSColor.white.withAlphaComponent(0.66),
        trackFill: NSColor(calibratedRed: 0.760, green: 0.858, blue: 0.902, alpha: 0.72),
        baselineStroke: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.48),
        mintAccent: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
        amberAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
        coralAccent: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
        blueAccent: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96),
        mintSoft: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.14),
        amberSoft: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.16),
        coralSoft: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.14),
        blueSoft: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.12),
        quotaLowEnd: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
        quotaHighEnd: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
        resetMidAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
        menuDarkPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.88),
            border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.54),
            track: NSColor.white.withAlphaComponent(0.18),
            resetTrack: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.28),
            primaryText: NSColor.white.withAlphaComponent(0.96),
            secondaryText: NSColor.white.withAlphaComponent(0.72),
            mutedText: NSColor.white.withAlphaComponent(0.44)
        ),
        menuLightPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 0.92),
            border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.76),
            track: NSColor(calibratedRed: 0.760, green: 0.858, blue: 0.902, alpha: 0.76),
            resetTrack: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.26),
            primaryText: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.94),
            secondaryText: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.74),
            mutedText: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.54)
        )
    )
}
```

- [ ] **Step 3: Route theme selection through Blue Ceramic**

Modify `currentSignalConsoleTheme()`:

```swift
private func currentSignalConsoleTheme() -> SignalConsoleTheme {
    switch currentSignalConsoleThemeKey() {
    case blueCeramicThemeKey:
        return blueCeramicTheme()
    case porcelainLabThemeKey:
        return porcelainLabTheme()
    case signalDarkThemeKey:
        return signalDarkTheme()
    case monoGraphiteThemeKey:
        return monoGraphiteTheme()
    default:
        return blueCeramicTheme()
    }
}
```

Modify `currentSignalConsoleThemeKey()`:

```swift
private func currentSignalConsoleThemeKey() -> String {
    let key = sessionSignalConsoleThemeKey
    switch key {
    case blueCeramicThemeKey, porcelainLabThemeKey, paperConsoleThemeKey, signalDarkThemeKey, monoGraphiteThemeKey:
        return key
    default:
        return blueCeramicThemeKey
    }
}
```

- [ ] **Step 4: Update menu bar battery color helpers**

Add these helpers near the existing battery drawing helpers:

```swift
private func batterySignalColor(_ status: BatteryStatus?) -> NSColor {
    guard let status, status.hasBattery else {
        return textMuted
    }
    if let percent = status.percent, percent < 15 {
        return coralAccent
    }
    return blueAccent
}

private func batterySoftFillColor(_ status: BatteryStatus?) -> NSColor {
    let color = batterySignalColor(status)
    return color.withAlphaComponent(status?.powerSaverActive == true ? 0.14 : 0.10)
}
```

Modify `drawMenuBarBattery(status:rect:palette:)` so the shell fill uses the selected blue semantic instead of warning amber:

```swift
private func drawMenuBarBattery(status: BatteryStatus?, rect: NSRect, palette: GaugePalette) {
    guard status?.hasBattery == true else {
        return
    }
    let color = batteryMenuBarColor(status, palette: palette)
    let shell = NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 1.2), xRadius: 3.0, yRadius: 3.0)
    color.withAlphaComponent(status?.isPluggedIn == true ? 0.16 : 0.24).setFill()
    shell.fill()
    color.withAlphaComponent(0.76).setStroke()
    shell.lineWidth = 0.7
    shell.stroke()
    drawMenuBarBatteryTerminal(rect: rect, color: color)
    drawMenuBarBatteryFill(status: status, rect: rect.insetBy(dx: 3.1, dy: 3.7), color: color)
}
```

Modify `batteryMenuBarColor(_:,palette:)`:

```swift
private func batteryMenuBarColor(_ status: BatteryStatus?, palette: GaugePalette) -> NSColor {
    guard let status, status.hasBattery else {
        return palette.mutedText
    }
    if let percent = status.percent, percent < 15 {
        return criticalQuotaColor
    }
    return currentSignalConsoleTheme().blueAccent
}
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_blue_ceramic_is_default_redesign_theme tests.test_signal_console_ux.SignalConsoleUXTests.test_battery_uses_blue_semantics_not_amber_in_power_saver -v
```

Expected: PASS after Task 2. If the dedicated battery strip test still fails, leave it for Task 3.

- [ ] **Step 6: Commit Task 2**

Run:

```bash
git add native/CodexGauge.swift
git commit -m "feat: add blue ceramic theme and battery colors"
```

Expected: commit succeeds.

---

### Task 3: Implement Signal Console Hierarchy And Dedicated Battery Mode Strip

**Files:**
- Modify: `native/CodexGauge.swift`
- Test: `tests/test_signal_console_ux.py`

- [ ] **Step 1: Add a dedicated battery strip rectangle to `SignalConsoleLayout`**

Update the layout geometry so the battery strip sits between quota rows and movement/summary:

```swift
    var batteryModeStripRect: NSRect {
        NSRect(x: margin, y: 270, width: bounds.width - margin * 2, height: 46)
    }

    var trendCardRect: NSRect {
        NSRect(x: margin, y: 328, width: 248, height: 104)
    }

    var healthRibbonRect: NSRect {
        NSRect(x: margin, y: 444, width: bounds.width - margin * 2, height: 54)
    }

    var bottomCommandButtonRects: [NSRect] {
        [
            NSRect(x: margin, y: 508, width: 122, height: 36),
            NSRect(x: margin + 130, y: 508, width: 122, height: 36),
            NSRect(x: margin + 260, y: 508, width: 122, height: 36),
            NSRect(x: margin + 390, y: 508, width: 130, height: 36),
        ]
    }
```

Keep `signalPopoverSize = NSSize(width: 560, height: 560)` unless text clips in screenshot verification. If it clips, increase to `NSSize(width: 560, height: 586)` and update tests accordingly.

- [ ] **Step 2: Draw the battery strip between quota and movement sections**

Modify `drawSignalConsolePanel()`:

```swift
private func drawSignalConsolePanel() {
    drawPanelBackground()
    drawHeader()
    drawStatusStrip()
    drawSignalHeroCard()
    drawBatteryModeStrip()
    drawTrendSection()
    drawReportSection()
    drawHealthRibbon()
    drawDivider(y: 502)
}
```

Add the new strip:

```swift
private func drawBatteryModeStrip() {
    let layout = SignalConsoleLayout(bounds: bounds)
    let rect = layout.batteryModeStripRect
    let color = batterySignalColorForPanel()
    drawRoundedRect(rect, radius: 14, fill: color.withAlphaComponent(0.10), stroke: color.withAlphaComponent(0.38))
    drawSignalConsoleBatteryIcon(percent: model.batteryPercent, rect: NSRect(x: rect.minX + 16, y: rect.minY + 11, width: 38, height: 22), color: color)
    drawText("Battery mode", x: rect.minX + 66, y: rect.minY + 10, width: 96, height: 16, size: 12, weight: .bold, color: textPrimary)
    drawText(model.powerSaverText, x: rect.minX + 66, y: rect.minY + 27, width: 150, height: 12, size: 8.6, weight: .medium, color: textMuted)
    drawText(model.refreshCadenceText, x: rect.minX + 174, y: rect.minY + 11, width: 110, height: 16, size: 12, weight: .medium, color: color, mono: true)
    drawText(model.batteryStatusText, x: rect.maxX - 108, y: rect.minY + 11, width: 86, height: 16, size: 11, weight: .semibold, color: textSecondary, mono: true)
}

private func batterySignalColorForPanel() -> NSColor {
    if let percent = model.batteryPercent, percent < 15 {
        return coralAccent
    }
    return blueAccent
}
```

- [ ] **Step 3: Remove the old amber battery row from the Movement card**

Modify `drawTrendSection()` so it does not call `drawBatteryModeStatusRow(in:)` in the `else` branch. Replace that branch with a concise note inside the Movement card:

```swift
        if hardwareSignalsVisible() {
            drawSystemMetricMovementRows(in: card)
            drawTemperatureMovementRow(in: card)
            drawBatteryStatusRow(in: card)
        } else {
            drawBatteryOnlyMovementNote(in: card)
        }
```

Add:

```swift
private func drawBatteryOnlyMovementNote(in card: NSRect) {
    drawText("Battery mode", x: card.minX + 16, y: card.minY + 91, width: 86, height: 12, size: 8.4, weight: .bold, color: blueAccent)
    drawText("Extra hardware signals paused", x: card.minX + 96, y: card.minY + 91, width: card.width - 112, height: 12, size: 7.6, weight: .medium, color: textMuted)
}
```

Leave `drawBatteryModeStatusRow(in:)` in place only if another test or preview still calls it. If nothing calls it after this task, remove the function.

- [ ] **Step 4: Rename visible report section copy to summary copy**

Modify `drawReportSection()`:

```swift
drawText("Usage summary", x: card.minX + 16, y: card.minY + 14, width: 118, height: 18, size: 12, weight: .bold, color: textPrimary)
```

Keep internal functions named `generateUsageReport` if changing them would make the patch too broad. Visible copy is the contract.

- [ ] **Step 5: Run focused tests**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux -v
```

Expected: PASS or fail only on fixture-name expectations deferred to Task 5. Fix any layout/token failures in this task before continuing.

- [ ] **Step 6: Commit Task 3**

Run:

```bash
git add native/CodexGauge.swift tests/test_signal_console_ux.py
git commit -m "feat: redesign signal console hierarchy"
```

Expected: commit succeeds.

---

### Task 4: Redesign Utility Windows And Update Prompt Behavior

**Files:**
- Modify: `native/CodexGauge.swift`
- Modify: `docs/PRIVACY.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Test: `tests/test_native_hardening.py`

- [ ] **Step 1: Update theme popup and preferences copy**

In `makePreferencesWindow()`, include Blue Ceramic as the first theme:

```swift
themeSelect.addItems(withTitles: ["Blue Ceramic", "Porcelain Lab", "Signal Dark", "Mono Graphite"])
themeSelect.item(withTitle: "Blue Ceramic")?.representedObject = blueCeramicThemeKey
themeSelect.item(withTitle: "Porcelain Lab")?.representedObject = porcelainLabThemeKey
themeSelect.item(withTitle: "Signal Dark")?.representedObject = signalDarkThemeKey
themeSelect.item(withTitle: "Mono Graphite")?.representedObject = monoGraphiteThemeKey
```

Update the zero-persistence label:

```swift
content.addSubview(utilityLabel("Zero persistence: no stored cache, snapshot, usage history, report file, or app log.", frame: NSRect(x: 24, y: 18, width: 372, height: 18), size: 11, weight: .regular, color: theme.textMuted))
```

Add update and battery controls only if they fit without clipping. If the current 420x380 window clips, resize to:

```swift
contentRect: NSRect(x: 0, y: 0, width: 620, height: 520)
```

- [ ] **Step 2: Add privacy-safe Setup Doctor labels**

Change Setup Doctor actions:

```swift
let refresh = NSButton(title: "Run Full Diagnostics", target: self, action: #selector(openSetupDoctor))
refresh.frame = NSRect(x: 24, y: 20, width: 144, height: 28)
styleUtilityButton(refresh)
content.addSubview(refresh)

let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
diagnostics.frame = NSRect(x: 176, y: 20, width: 136, height: 28)
styleUtilityButton(diagnostics, primary: true)
content.addSubview(diagnostics)
```

Keep all DoctorCheck details path-free. If adding disk access or battery access rows, use wording like `Read & write` and `Allowed`, never actual paths.

- [ ] **Step 3: Rename update skip state and button labels**

Rename the in-memory automatic update field:

```swift
private var automaticUpdateSkippedTagName: String?
```

Update `handleLatestRelease(_:,mode:)`:

```swift
if mode == .automatic, automaticUpdateSkippedTagName == release.tagName {
    return
}
```

Modify `showUpdatePrompt(release:asset:latestVersion:mode:)`:

```swift
private func showUpdatePrompt(release: GitHubRelease, asset: GitHubReleaseAsset, latestVersion: String, mode: UpdateCheckMode) {
    let alert = NSAlert()
    alert.messageText = "Update Available"
    alert.informativeText = releaseInfoText(release: release, asset: asset, latestVersion: latestVersion)
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Install Update")
    alert.addButton(withTitle: "Skip this version")
    alert.addButton(withTitle: "Remind me later")
    switch alert.runModal() {
    case .alertFirstButtonReturn:
        downloadAndInstallUpdate(release: release, asset: asset, latestVersion: latestVersion)
    case .alertSecondButtonReturn:
        automaticUpdateSkippedTagName = release.tagName
        lastUpdateSummary = "Update skipped: \(release.tagName)"
        rebuildMenu()
    default:
        if mode == .automatic {
            lastUpdateSummary = "Update postponed: \(release.tagName)"
            rebuildMenu()
        }
    }
}
```

Manual `Check for Updates...` must still show the skipped version because the user requested it.

- [ ] **Step 4: Update public privacy wording**

In `docs/PRIVACY.md`, replace the updater phrasing around dismissed versions with:

```markdown
- Codex Gauge may remember a skipped update version in memory for the current app session so it does not keep prompting for the same release.
- It does not write update history, skipped-version records, release notes, or downloaded update metadata to app storage.
```

In `README.md`, add:

```markdown
Update prompts include release notes and three choices: Install Update, Skip this version, or Remind me later. Skipping is session-only and prevents repeat prompts for that release while the app is running.
```

Add the equivalent short note to `README.zh-CN.md`.

- [ ] **Step 5: Run focused tests**

Run:

```bash
python3 -m unittest tests.test_native_hardening -v
```

Expected: PASS. If existing tests still expect `no dismissed-version record`, update them to the new session-only skip wording from Task 1.

- [ ] **Step 6: Commit Task 4**

Run:

```bash
git add native/CodexGauge.swift docs/PRIVACY.md README.md README.zh-CN.md tests/test_native_hardening.py
git commit -m "feat: polish utility windows and updater prompt"
```

Expected: commit succeeds.

---

### Task 5: Regenerate Fixtures And Public Visual Assets

**Files:**
- Modify: `native/CodexGauge.swift`
- Modify: `script/generate_theme_state_previews.swift`
- Modify: `script/generate_public_assets.swift`
- Modify generated PNGs under `docs/design/` and `docs/assets/`
- Test: `tests/test_public_release_hygiene.py`

- [ ] **Step 1: Update preview fixture slugs**

In `signalConsolePreviewCases()`, replace the theme list with:

```swift
let themes: [(slug: String, theme: SignalConsoleTheme)] = [
    ("blue-ceramic", blueCeramicTheme()),
    ("signal-dark", signalDarkTheme()),
    ("mono-graphite", monoGraphiteTheme()),
]
```

Ensure the `battery-mode` preview model uses:

```swift
powerSaverText: "Power Saver active",
refreshCadenceText: "Refresh 60m",
hardwareSignalsVisible: false
```

- [ ] **Step 2: Update `script/generate_theme_state_previews.swift`**

Replace the first `PreviewTheme` entry with Blue Ceramic tokens:

```swift
PreviewTheme(
    name: "Blue Ceramic",
    background: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
    panel: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0),
    panelSoft: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
    border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.88),
    text: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.98),
    secondary: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.92),
    muted: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.82),
    mint: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
    amber: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
    coral: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
    blue: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96)
)
```

Add a state named `Battery mode` if the state grid has room. If it does not, keep the four-state grid and make sure `Live only` source text says `Storage: Zero persistence`.

- [ ] **Step 3: Update public asset generator paths and copy**

In `script/generate_public_assets.swift`, change:

```swift
let porcelainFixturePath = "docs/design/app-rendered-signal-console/blue-ceramic-live.png"
```

Keep `darkFixturePath` as Signal Dark unless the social asset should also use Blue Ceramic. Update visible copy from `Local report` to `Live summary`:

```swift
drawPill("Live summary", rect: NSRect(x: 352, y: 280, width: 144, height: 38), fill: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.09), stroke: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.20), text: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 1.0))
```

- [ ] **Step 4: Regenerate fixtures**

Run:

```bash
./script/build_and_run.sh --build-only
script/render_signal_console_fixtures.sh
swift script/generate_theme_state_previews.swift
swift script/generate_public_assets.swift
```

Expected:

- Build succeeds.
- `docs/design/app-rendered-signal-console/blue-ceramic-live.png` exists.
- `docs/design/app-rendered-signal-console/blue-ceramic-battery-mode.png` exists.
- `docs/design/codex-gauge-theme-state-fixtures.png` is regenerated.
- `docs/assets/codex-gauge-signal-console.png` is regenerated.
- `docs/assets/codex-gauge-social-preview.png` is regenerated.

- [ ] **Step 5: Run asset tests**

Run:

```bash
python3 -m unittest tests.test_public_release_hygiene -v
```

Expected: PASS.

- [ ] **Step 6: Inspect generated images**

Run visual inspection on:

```text
docs/design/app-rendered-signal-console/blue-ceramic-live.png
docs/design/app-rendered-signal-console/blue-ceramic-battery-mode.png
docs/design/codex-gauge-theme-state-fixtures.png
docs/assets/codex-gauge-signal-console.png
```

Expected:

- Battery icon is blue in normal and battery mode.
- Battery strip is blue-tinted, not amber.
- Reset timing remains amber.
- Low quota and negative movement remain coral.
- No personal paths appear in utility screens.

- [ ] **Step 7: Commit Task 5**

Run:

```bash
git add native/CodexGauge.swift script/generate_theme_state_previews.swift script/generate_public_assets.swift docs/design docs/assets tests/test_public_release_hygiene.py
git commit -m "docs: refresh blue ceramic visual assets"
```

Expected: commit succeeds.

---

### Task 6: Full Verification, Install, Screenshots, And Final Review

**Files:**
- Modify only if verification exposes a defect.
- Read/inspect: `docs/design/porcelain-circuit-blue-ceramic-final-battery-blue.png`
- Produce temporary screenshots under `/tmp/`

- [ ] **Step 1: Run full tests**

Run:

```bash
python3 -m unittest discover -s tests -v
```

Expected: PASS.

- [ ] **Step 2: Run build and release checks**

Run:

```bash
./script/build_and_run.sh --build-only
script/release_check.sh
```

Expected: both pass.

- [ ] **Step 3: Install the local app**

Run:

```bash
script/replace_installed_app.sh
```

Expected:

- `/Applications/CodexGauge.app` is replaced.
- The app opens in the macOS menu bar.
- No LaunchAgent or legacy support folder is recreated.

- [ ] **Step 4: Capture implementation screenshots**

Capture at least:

```bash
screencapture -x /tmp/codex-gauge-blue-ceramic-screen.png
```

If the popover or utility windows need manual opening, open them from the menu bar and capture:

```bash
screencapture -x /tmp/codex-gauge-blue-ceramic-popover.png
screencapture -x /tmp/codex-gauge-blue-ceramic-preferences.png
screencapture -x /tmp/codex-gauge-blue-ceramic-doctor.png
```

Expected: screenshots exist and show the Blue Ceramic UI.

- [ ] **Step 5: Use visual inspection against the accepted concept**

Inspect these images:

```text
docs/design/porcelain-circuit-blue-ceramic-final-battery-blue.png
/tmp/codex-gauge-blue-ceramic-screen.png
/tmp/codex-gauge-blue-ceramic-popover.png
/tmp/codex-gauge-blue-ceramic-preferences.png
/tmp/codex-gauge-blue-ceramic-doctor.png
```

Comparison checklist:

- Palette: porcelain/frost/ink/teal/blue/amber/coral are visibly distinct.
- Battery: blue in normal and battery mode, coral only when low, never amber.
- Reset: amber lane and timing remain amber.
- Signal Console hierarchy: quota first, battery/refresh second, diagnostics lower.
- Privacy: no personal paths, `Share Report`, saved report wording, cookies, auth, or logs in visible utility UI.
- Power: on-battery copy shows slowed refresh cadence.
- Typography: text fits in buttons, rows, and utility windows.

- [ ] **Step 6: Run git review**

Run:

```bash
git status --short
git diff --stat
git diff -- native/CodexGauge.swift tests/test_signal_console_ux.py tests/test_native_hardening.py tests/test_public_release_hygiene.py docs/PRIVACY.md README.md README.zh-CN.md script/generate_theme_state_previews.swift script/generate_public_assets.swift
```

Expected: only intended redesign files changed.

- [ ] **Step 7: Commit final fixes if needed**

If verification required fixes, commit them:

```bash
git add native/CodexGauge.swift tests docs README.md README.zh-CN.md script
git commit -m "fix: align blue ceramic verification details"
```

If no fixes were needed, do not create an empty commit.

- [ ] **Step 8: Push after final verification**

Run:

```bash
git push origin main
```

Expected: push succeeds.

---

## Plan Self-Review

Spec coverage:

- Menu bar gauge: Task 2 and Task 6.
- Signal Console popover: Task 3 and Task 5.
- Battery mode and refresh cadence states: Tasks 1, 2, 3, 4, and 6.
- Preferences: Task 4.
- Setup Doctor: Task 4.
- Update prompt: Task 4.
- Zero-persistence and diagnostics copy: Tasks 1, 4, and 6.
- Visual fixtures and accepted concept comparison: Tasks 5 and 6.

Placeholder scan:

- The plan contains no unresolved placeholder instructions.
- Every task has exact files, concrete code snippets, commands, and expected results.

Type consistency:

- Theme key is consistently `blueCeramicThemeKey`.
- Theme function is consistently `blueCeramicTheme()`.
- Battery color helper is consistently `batterySignalColor`.
- Updater skip field is consistently `automaticUpdateSkippedTagName`.
