# Temperature History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 1-second SSD temperature sampler, compact the menu bar while preserving all current signals, and render a smooth 60-second SSD temperature curve inside the Signal Console Movement section.

**Architecture:** Keep the existing local `ssd_temperature` helper. Add a bounded `TemperatureSample` model plus a 1-second AppKit timer in `CodexGaugeApp`, expose recent samples through `SignalConsoleModel`, and render the selected smooth-curve design in `SignalConsolePanelView`. Persist samples to a dedicated bounded JSON file so Clear local data and future reports have one clear ownership boundary.

**Tech Stack:** Swift/AppKit single-file native app, Objective-C/C helper already bundled as `native/ssd_temperature.m`, Python unittest source assertions, existing Swift fixture renderer and release scripts.

---

## File Structure

- Modify `native/CodexGauge.swift`
  - Add `TemperatureSample`.
  - Add temperature-history state, timer, persistence, retention, and clear-data support.
  - Add model fields for current temperature, temperature samples, and unavailable copy.
  - Compact menu-bar geometry.
  - Draw the smooth SSD temperature curve inside the Movement card.
- Modify `tests/test_signal_console_ux.py`
  - Add focused source-level regression tests for sampler, persistence, compact menu bar, and Movement curve.
- Modify `tests/test_native_hardening.py`
  - Extend local-data/privacy assertions for bounded temperature history.
- Modify `tests/test_public_readme_package.py`
  - Add README expectations for 1-second local temperature history and Clear local data.
- Modify `README.md` and `README.zh-CN.md`
  - Document optional SSD temperature history as local-only.
- Regenerate `docs/design/app-rendered-signal-console/*.png` and `docs/assets/*.png` after implementation.

---

### Task 1: Temperature Sampler and Bounded Storage

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `tests/test_native_hardening.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write failing tests for the sampler and storage**

Add these tests to `tests/test_signal_console_ux.py`:

```python
    def test_ssd_temperature_history_samples_every_second_and_is_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct TemperatureSample: Codable", source)
        self.assertIn("private var temperatureTimer: Timer?", source)
        self.assertIn("private var temperatureSamples: [TemperatureSample] = []", source)
        self.assertIn('private let temperatureSampleInterval: TimeInterval = 1', source)
        self.assertIn("private let temperatureHistoryWindow: TimeInterval = 60", source)
        self.assertIn("private let maxTemperatureSamples = 90", source)
        self.assertIn("startTemperatureSampler()", source)
        self.assertIn("sampleTemperature()", source)
        self.assertIn("Timer(timeInterval: temperatureSampleInterval, repeats: true)", source)
        self.assertIn("appendTemperatureSample(status)", source)
        self.assertIn("retainedTemperatureSamples", source)
        self.assertIn("writeTemperatureSamples", source)
        self.assertIn("readTemperatureSamples", source)
```

Add this test to `tests/test_native_hardening.py`:

```python
    def test_temperature_history_is_local_bounded_and_clearable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('temperatureHistoryFileName = "CodexGauge-temperature-history.json"', source)
        self.assertIn("temperatureHistoryPath", source)
        self.assertIn("maxTemperatureSamples = 90", source)
        self.assertIn("temperatureHistoryWindow: TimeInterval = 60", source)
        self.assertIn("retainedTemperatureSamples", source)
        self.assertIn("temperatureHistoryPath,", source)
        self.assertIn("Clear local data", source)
        self.assertNotIn("Keychain", source[source.find("private func appendTemperatureSample"):source.find("private func readTemperatureSamples")])
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_ssd_temperature_history_samples_every_second_and_is_bounded \
  tests.test_native_hardening.NativeHardeningTests.test_temperature_history_is_local_bounded_and_clearable \
  -v
```

Expected: FAIL because `TemperatureSample`, timer, storage constants, and clear-data path are not implemented.

- [ ] **Step 3: Implement minimal sampler and storage**

In `native/CodexGauge.swift`, add near `HistorySample`:

```swift
private struct TemperatureSample: Codable {
    let time: String
    let temperatureC: Int?
    let ok: Bool
}
```

Add state and constants near the existing app properties:

```swift
    private var temperatureTimer: Timer?
    private var temperatureSamples: [TemperatureSample] = []
    private let temperatureSampleInterval: TimeInterval = 1
    private let temperatureHistoryWindow: TimeInterval = 60
    private let maxTemperatureSamples = 90
    private let temperatureHistoryFileName = "CodexGauge-temperature-history.json"
```

Add the path near `historyPath`:

```swift
    private lazy var temperatureHistoryPath = "\(supportDir)/\(temperatureHistoryFileName)"
```

In `applicationDidFinishLaunching`, after initial setup but before `refresh()` starts long-running work, load and start:

```swift
        temperatureSamples = readTemperatureSamples()
        startTemperatureSampler()
```

Add the sampler methods near `readSSDTemperature()`:

```swift
    private func startTemperatureSampler() {
        temperatureTimer?.invalidate()
        sampleTemperature()
        let nextTimer = Timer(timeInterval: temperatureSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleTemperature()
        }
        temperatureTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func sampleTemperature() {
        let status = readSSDTemperature()
        ssdTemperature = status
        appendTemperatureSample(status)
        if let button = statusItem.button {
            button.image = makeStatusImage(
                fiveHourLeft: snapshot?.codex.fiveHourLeft,
                sevenDayLeft: snapshot?.codex.sevenDayLeft,
                fiveHourReset: snapshot?.codex.fiveHourReset,
                sevenDayReset: snapshot?.codex.sevenDayReset,
                source: snapshot?.codex.source,
                ssdTemperature: ssdTemperature
            )
        }
        if signalPopover?.isShown == true {
            refreshSignalPopoverIfNeeded()
        }
    }

    private func appendTemperatureSample(_ status: SSDTemperatureStatus?) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let sample = TemperatureSample(
            time: formatter.string(from: Date()),
            temperatureC: status?.ok == true ? status?.temperatureC : nil,
            ok: status?.ok == true && status?.temperatureC != nil
        )
        temperatureSamples.append(sample)
        temperatureSamples = retainedTemperatureSamples(temperatureSamples)
        writeTemperatureSamples(temperatureSamples)
    }

    private func readTemperatureSamples() -> [TemperatureSample] {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: temperatureHistoryPath)),
            let samples = try? JSONDecoder().decode([TemperatureSample].self, from: data)
        else {
            return []
        }
        return retainedTemperatureSamples(samples)
    }

    private func writeTemperatureSamples(_ samples: [TemperatureSample]) {
        do {
            let data = try JSONEncoder().encode(retainedTemperatureSamples(samples))
            try FileManager.default.createDirectory(
                atPath: (temperatureHistoryPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try data.write(to: URL(fileURLWithPath: temperatureHistoryPath), options: .atomic)
        } catch {
            appendLog("temperature history write failed=\(error.localizedDescription)")
        }
    }

    private func retainedTemperatureSamples(_ samples: [TemperatureSample], now: Date = Date()) -> [TemperatureSample] {
        let cutoff = now.addingTimeInterval(-temperatureHistoryWindow)
        let recent = samples.filter { sample in
            guard let date = isoDate(sample.time) else {
                return false
            }
            return date >= cutoff
        }
        return Array(recent.suffix(maxTemperatureSamples))
    }
```

In `localDataPathsForClearing`, add `temperatureHistoryPath` to the returned array:

```swift
            temperatureHistoryPath,
```

In the existing `applicationWillTerminate`, add `temperatureTimer?.invalidate()`:

```swift
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        animationTimer?.invalidate()
        popoverCountdownTimer?.invalidate()
        temperatureTimer?.invalidate()
    }
```

- [ ] **Step 4: Run task tests and verify they pass**

Run the same focused command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add native/CodexGauge.swift tests/test_signal_console_ux.py tests/test_native_hardening.py
git commit -m "feat: add bounded temperature sampler"
```

---

### Task 2: Compact Menu Bar Redesign

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write failing compact menu-bar test**

Update `test_menu_bar_integrates_ssd_temperature_without_removing_current_quota_info` in `tests/test_signal_console_ux.py` so it expects the shorter layout:

```python
        self.assertIn("statusItemWidth: CGFloat = 174", source)
        self.assertIn("statusImageSize = NSSize(width: 168", source)
        self.assertIn("private let quotaRailWidth: CGFloat = 28", source)
        self.assertIn("private let resetRailWidth: CGFloat = 18", source)
        self.assertIn("private let menuBarTemperatureChipRect = NSRect(x: 82", source)
        self.assertIn("width: 27, height: 12.2", source)
        self.assertIn("drawPlanBRow(window: \"5h\"", source)
        self.assertIn("drawPlanBRow(window: \"7d\"", source)
        self.assertIn("drawQuotaRail(value: quotaLeft", source)
        self.assertIn("drawResetMoodLane(value: resetProgress", source)
        self.assertIn("fiveHourResetCountdown(resetEpoch)", source)
        self.assertIn("sevenDayResetCountdown(resetEpoch)", source)
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_integrates_ssd_temperature_without_removing_current_quota_info -v
```

Expected: FAIL on old width and geometry values.

- [ ] **Step 3: Implement compact menu-bar geometry**

In `native/CodexGauge.swift`, change the menu-bar constants:

```swift
    private let statusItemWidth: CGFloat = 174
    private let statusImageSize = NSSize(width: 168, height: 22)
    private let menuBarTemperatureChipRect = NSRect(x: 82, y: 4.9, width: 27, height: 12.2)
    private let quotaRailWidth: CGFloat = 28
    private let resetRailWidth: CGFloat = 18
```

Update `drawPlanBRow` positions so existing information remains visible:

```swift
        drawQuotaRail(value: quotaLeft, rect: NSRect(x: 24, y: y, width: quotaRailWidth, height: 3), palette: palette)

        let percentText = quotaLeft.map { "\($0)%" } ?? "--"
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.7, weight: .semibold),
            .foregroundColor: quotaLeft == nil ? palette.mutedText : palette.primaryText,
        ]
        (percentText as NSString).draw(at: NSPoint(x: 55, y: y - 3.1), withAttributes: valueAttrs)

        let resetProgress = resetProgressPercent(epoch: resetEpoch, windowHours: windowHours)
        drawResetMoodLane(value: resetProgress, rect: NSRect(x: 116, y: y, width: resetRailWidth + 6, height: 3), palette: palette)

        let resetText = window == "5h" ? fiveHourResetCountdown(resetEpoch) : sevenDayResetCountdown(resetEpoch)
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 5.7, weight: .semibold),
            .foregroundColor: resetEpoch == nil ? palette.mutedText : palette.secondaryText,
        ]
        (resetText as NSString).draw(at: NSPoint(x: 143, y: y - 2.9), withAttributes: resetAttrs)
```

If the unavailable state text overlaps, reduce `drawUnavailableGauge` action text width or position to fit the new `168` width.

- [ ] **Step 4: Run compact menu-bar test and build**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_integrates_ssd_temperature_without_removing_current_quota_info -v
./script/build_and_run.sh --build-only
```

Expected: test PASS and build exit 0.

- [ ] **Step 5: Commit Task 2**

```bash
git add native/CodexGauge.swift tests/test_signal_console_ux.py
git commit -m "feat: compact menu bar gauge"
```

---

### Task 3: Signal Console Smooth Temperature Curve

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write failing Movement-section tests**

Add this test to `tests/test_signal_console_ux.py`:

```python
    def test_signal_console_movement_shows_smooth_temperature_curve(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("temperatureHistory: [TemperatureSample]", source)
        self.assertIn("currentTemperatureText: String", source)
        self.assertIn("temperatureHistoryText: String", source)
        self.assertIn("temperatureHistory: retainedTemperatureSamples(temperatureSamples)", source)
        self.assertIn('"SSD temp"', source)
        self.assertIn('"last 60s"', source)
        self.assertIn('"SSD temp unavailable"', source)
        self.assertIn("drawTemperatureCurve", source)
        self.assertIn("smoothedTemperaturePoints", source)
        self.assertIn("temperatureCurveColor", source)
        self.assertIn("drawTemperatureUnavailableCurve", source)
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_signal_console_movement_shows_smooth_temperature_curve -v
```

Expected: FAIL because `SignalConsoleModel` does not expose temperature history and the renderer has no curve.

- [ ] **Step 3: Extend the Signal Console model**

Add fields to `SignalConsoleModel`:

```swift
    let temperatureHistory: [TemperatureSample]
    let currentTemperatureText: String
    let temperatureHistoryText: String
```

In every `SignalConsoleModel(...)` initializer path, pass:

```swift
                temperatureHistory: retainedTemperatureSamples(temperatureSamples),
                currentTemperatureText: ssdTemperatureDisplayText(ssdTemperature),
                temperatureHistoryText: temperatureHistorySummaryText(retainedTemperatureSamples(temperatureSamples)),
```

Add helper:

```swift
    private func temperatureHistorySummaryText(_ samples: [TemperatureSample]) -> String {
        let valid = samples.filter { $0.ok && $0.temperatureC != nil }
        guard valid.count >= 2 else {
            return "SSD temp unavailable"
        }
        return "last 60s"
    }
```

For preview fixtures, add a deterministic sample builder near the existing fixture model helpers:

```swift
private func previewTemperatureSamples(unavailable: Bool = false) -> [TemperatureSample] {
    guard !unavailable else {
        return []
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let now = Date(timeIntervalSince1970: 1_781_600_000)
    let values = [42, 42, 43, 44, 45, 44, 43, 43, 44, 44, 45, 44]
    return values.enumerated().map { index, value in
        TemperatureSample(
            time: formatter.string(from: now.addingTimeInterval(Double(index - values.count))),
            temperatureC: value,
            ok: true
        )
    }
}
```

- [ ] **Step 4: Draw the smooth curve in Movement**

In `drawTrendSection`, keep the card title but draw quota movement in a tighter top block and temperature movement below it:

```swift
        drawText("Movement", x: card.minX + 16, y: card.minY + 14, width: 126, height: 18, size: 12, weight: .bold, color: textPrimary)
        drawText("last 24h", x: card.maxX - 62, y: card.minY + 14, width: 46, height: 18, size: 10, weight: .regular, color: textMuted)
        drawTrendRow(label: "5h", text: model.fiveHourTrendText, values: model.fiveHourHistory, y: 318)
        drawTrendRow(label: "7d", text: model.sevenDayTrendText, values: model.sevenDayHistory, y: 346)
        drawTemperatureMovementRow(in: NSRect(x: card.minX + 16, y: card.minY + 74, width: card.width - 32, height: 38))
        drawTrendContext()
```

Add methods inside `SignalConsolePanelView`:

```swift
    private func drawTemperatureMovementRow(in rect: NSRect) {
        drawText("SSD temp", x: rect.minX, y: rect.minY, width: 64, height: 14, size: 10.5, weight: .bold, color: textSecondary)
        drawText(model.temperatureHistoryText, x: rect.minX, y: rect.minY + 16, width: 70, height: 14, size: 8.5, weight: .regular, color: textMuted)
        let curveRect = NSRect(x: rect.minX + 72, y: rect.minY + 2, width: rect.width - 116, height: 30)
        if model.temperatureHistory.filter({ $0.ok && $0.temperatureC != nil }).count >= 2 {
            drawTemperatureCurve(samples: model.temperatureHistory, rect: curveRect)
        } else {
            drawTemperatureUnavailableCurve(rect: curveRect)
        }
        drawText(model.currentTemperatureText, x: rect.maxX - 38, y: rect.minY + 8, width: 38, height: 18, size: 12, weight: .bold, color: temperatureCurveColor(samples: model.temperatureHistory), mono: true)
    }

    private func drawTemperatureCurve(samples: [TemperatureSample], rect: NSRect) {
        drawRoundedRect(rect, radius: 7, fill: theme.commandButtonBackground.withAlphaComponent(0.42), stroke: panelBorder.withAlphaComponent(0.20))
        let points = smoothedTemperaturePoints(samples: samples, rect: rect.insetBy(dx: 5, dy: 5))
        guard points.count >= 2 else {
            drawTemperatureUnavailableCurve(rect: rect)
            return
        }
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: points[0].x, y: rect.maxY - 4))
        points.forEach { fillPath.line(to: $0) }
        fillPath.line(to: NSPoint(x: points.last?.x ?? rect.maxX, y: rect.maxY - 4))
        fillPath.close()
        temperatureCurveColor(samples: samples).withAlphaComponent(0.16).setFill()
        fillPath.fill()

        let line = NSBezierPath()
        line.move(to: points[0])
        for point in points.dropFirst() {
            line.line(to: point)
        }
        line.lineWidth = 2.0
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        temperatureCurveColor(samples: samples).setStroke()
        line.stroke()
    }

    private func drawTemperatureUnavailableCurve(rect: NSRect) {
        drawRoundedRect(rect, radius: 7, fill: theme.commandButtonBackground.withAlphaComponent(0.28), stroke: panelBorder.withAlphaComponent(0.16))
        let dash = NSBezierPath()
        dash.move(to: NSPoint(x: rect.minX + 6, y: rect.midY))
        dash.line(to: NSPoint(x: rect.maxX - 6, y: rect.midY))
        dash.lineWidth = 1
        let previous = NSGraphicsContext.current?.cgContext
        previous?.setLineDash(phase: 0, lengths: [3, 4])
        textMuted.withAlphaComponent(0.45).setStroke()
        dash.stroke()
        previous?.setLineDash(phase: 0, lengths: [])
    }

    private func smoothedTemperaturePoints(samples: [TemperatureSample], rect: NSRect) -> [NSPoint] {
        let valid = samples.suffix(60).compactMap { $0.temperatureC }
        guard valid.count >= 2 else {
            return []
        }
        let minValue = Double(valid.min() ?? 0)
        let maxValue = Double(valid.max() ?? 0)
        let range = max(4.0, maxValue - minValue)
        return valid.enumerated().map { index, value in
            let x = rect.minX + (rect.width * CGFloat(index) / CGFloat(max(1, valid.count - 1)))
            let normalized = (Double(value) - minValue) / range
            let y = rect.maxY - CGFloat(normalized) * rect.height
            return NSPoint(x: x, y: y)
        }
    }

    private func temperatureCurveColor(samples: [TemperatureSample]) -> NSColor {
        let current = samples.last(where: { $0.ok && $0.temperatureC != nil })?.temperatureC
        guard let current else {
            return textMuted
        }
        switch current {
        case 70...:
            return coralAccent
        case 55..<70:
            return amberAccent
        default:
            return mintAccent
        }
    }
```

- [ ] **Step 5: Run Movement test and fixture render**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_signal_console_movement_shows_smooth_temperature_curve -v
./script/build_and_run.sh --build-only
./native/dist/CodexGauge.app/Contents/MacOS/CodexGauge-bin --render-signal-console-fixtures docs/design/app-rendered-signal-console
swift script/generate_public_assets.swift
```

Expected: test PASS, build exit 0, fixture PNGs regenerated.

- [ ] **Step 6: Commit Task 3**

```bash
git add native/CodexGauge.swift tests/test_signal_console_ux.py docs/design/app-rendered-signal-console docs/assets
git commit -m "feat: show SSD temperature movement"
```

---

### Task 4: Documentation, Install, and Final Verification

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `tests/test_public_readme_package.py`
- Modify: `native/CodexGauge.swift` if final polish is needed

- [ ] **Step 1: Write failing README expectations**

In `tests/test_public_readme_package.py`, add expectations to the existing README tests:

```python
        self.assertIn("1-second local SSD temperature history", readme)
        self.assertIn("smooth 60-second temperature curve", readme)
        self.assertIn("Clear local data removes temperature history", readme)
```

For Chinese README expectations, add:

```python
        self.assertIn("1 秒本地 SSD 温度历史", zh_readme)
        self.assertIn("60 秒温度曲线", zh_readme)
```

- [ ] **Step 2: Run README tests and verify they fail**

Run:

```bash
python3 -m unittest tests.test_public_readme_package.PublicReadmePackageTests -v
```

Expected: FAIL because README copy has not been updated.

- [ ] **Step 3: Update README copy**

In `README.md`, add bullets near the SSD temperature explanation:

```markdown
- 1-second local SSD temperature history renders as a smooth 60-second temperature curve in the Movement section
  1 秒本地 SSD 温度历史会在 Movement 区域显示为平滑的 60 秒温度曲线
- Clear local data removes temperature history together with quota history, cache, and logs
  Clear local data 会同时删除温度历史、额度历史、缓存和日志
```

In `README.zh-CN.md`, add:

```markdown
- 1 秒本地 SSD 温度历史会在 Movement 区域显示为平滑的 60 秒温度曲线
- Clear local data 会同时删除温度历史、额度历史、缓存和日志
```

- [ ] **Step 4: Run full verification and install**

Run:

```bash
python3 -m unittest discover -s tests -v
./script/build_and_run.sh --build-only
./script/release_check.sh
./script/replace_installed_app.sh
```

Expected: all tests PASS, build exit 0, release check passed, `/Applications/CodexGauge.app` replaced.

- [ ] **Step 5: Visual verification**

Run:

```bash
screencapture -x /tmp/codex-gauge-temperature-history-screen.png
sips -c 120 820 --cropOffset 0 1560 /tmp/codex-gauge-temperature-history-screen.png --out /tmp/codex-gauge-temperature-history-menubar.png
```

Open `/tmp/codex-gauge-temperature-history-menubar.png` and `docs/assets/codex-gauge-social-preview.png`.

Expected:

- Menu bar is shorter than before.
- `44°`-style chip remains visible.
- 5h/7d rows, percentages, reset lanes, and reset countdowns remain visible.
- Signal Console Movement card shows an SSD temperature curve.

- [ ] **Step 6: Commit Task 4**

```bash
git add README.md README.zh-CN.md tests/test_public_readme_package.py native/CodexGauge.swift docs/assets docs/design/app-rendered-signal-console
git commit -m "docs: describe temperature history"
```

---

## Final Checks

After all task commits:

```bash
python3 -m unittest discover -s tests -v
./script/build_and_run.sh --build-only
./script/release_check.sh
git status --short
```

Expected:

- Tests pass.
- Build passes.
- Release check passes.
- Only intentional files remain changed.
