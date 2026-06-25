# Battery Power Saver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native battery glyph and automatic aggressive Power Saver behavior whenever Codex Gauge is running on battery.

**Architecture:** Keep Codex Gauge as a single native AppKit app, matching the current codebase. Add an in-memory battery reader based on macOS IOPS APIs, isolate Power Saver refresh/sampling policy in helper methods, then feed plain battery values into the existing menu-bar renderer, Signal Console model, diagnostics, and Setup Doctor.

**Tech Stack:** Swift/AppKit, IOKit power-source APIs, Python `unittest` source-level tests, existing shell build scripts.

---

## Scope Check

The approved spec is one cohesive feature: battery state plus Power Saver policy. It touches one runtime surface (`native/CodexGauge.swift`), build linking (`script/build_and_run.sh`), source-level tests, and public docs. It does not need a new helper binary, persisted battery history file, or separate subsystem.

## File Structure

- Modify `native/CodexGauge.swift`: add `BatteryStatus`, native battery reading, power-source notifications, Power Saver policy helpers, menu-bar glyph drawing, Signal Console fields, Setup Doctor, diagnostics, and sampler coordination.
- Modify `script/build_and_run.sh`: link the Swift app with `-framework IOKit`.
- Modify `tests/test_native_hardening.py`: verify native battery API usage, no battery history file, Power Saver intervals, and sampler throttling.
- Modify `tests/test_signal_console_ux.py`: verify menu-bar battery glyph, Signal Console battery fields, diagnostics, and Setup Doctor surface.
- Modify `tests/test_public_readme_package.py`: require README coverage for battery and Power Saver.
- Modify `README.md`, `README.zh-CN.md`, and `docs/PRIVACY.md`: document local-only battery telemetry and on-battery Power Saver behavior.

---

### Task 1: Native Battery Model and Reader

**Files:**
- Modify: `tests/test_native_hardening.py`
- Modify: `native/CodexGauge.swift`
- Modify: `script/build_and_run.sh`

- [ ] **Step 1: Write the failing native battery test**

Add this test method to `tests/test_native_hardening.py` inside `NativeHardeningTests`:

```python
    def test_battery_status_uses_native_iops_without_persisting_history(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        build_script = pathlib.Path("script/build_and_run.sh").read_text()

        for token in [
            "import IOKit.ps",
            "private struct BatteryStatus",
            "let percent: Int?",
            "let isPluggedIn: Bool?",
            "let isCharging: Bool?",
            "let hasBattery: Bool",
            "let powerSaverActive: Bool",
            "let source: String",
            "let error: String?",
            "private var batteryStatus: BatteryStatus?",
            "private var batteryTimer: Timer?",
            "private var batteryRunLoopSource: CFRunLoopSource?",
            "private let batterySampleInterval: TimeInterval = 60",
            "private func readBatteryStatus() -> BatteryStatus",
            "IOPSCopyPowerSourcesInfo()",
            "IOPSCopyPowerSourcesList",
            "IOPSGetPowerSourceDescription",
            "kIOPSInternalBatteryType",
            "kIOPSCurrentCapacityKey",
            "kIOPSMaxCapacityKey",
            "kIOPSPowerSourceStateKey",
            "kIOPSACPowerValue",
            "kIOPSBatteryPowerValue",
            "kIOPSIsChargingKey",
            "IOPSNotificationCreateRunLoopSource",
            "startBatterySampler()",
            "sampleBattery()",
        ]:
            self.assertIn(token, source)

        self.assertIn("-framework IOKit", build_script)
        self.assertNotIn("pmset", source)
        self.assertNotIn("ioreg", source)
        self.assertNotIn("Battery-history", source)
        self.assertNotIn("batteryHistoryPath", source)
        self.assertNotIn("CodexGauge-battery", source)
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_native_hardening.NativeHardeningTests.test_battery_status_uses_native_iops_without_persisting_history -v
```

Expected: `FAIL` because `BatteryStatus`, IOPS tokens, and `-framework IOKit` do not exist yet.

- [ ] **Step 3: Link IOKit for the Swift app**

In `script/build_and_run.sh`, update the `swiftc` line inside `build_bundle()` from:

```bash
    swiftc "$SOURCE_FILE" -o "$stage_binary" -framework Cocoa -framework UserNotifications
```

to:

```bash
    swiftc "$SOURCE_FILE" -o "$stage_binary" -framework Cocoa -framework UserNotifications -framework IOKit
```

- [ ] **Step 4: Add the IOKit import and battery model**

At the top of `native/CodexGauge.swift`, change the imports to:

```swift
import Cocoa
import Darwin
import Foundation
import IOKit.ps
import UserNotifications
```

After `private struct SystemMetricSample: Codable`, add:

```swift
private struct BatteryStatus {
    let percent: Int?
    let isPluggedIn: Bool?
    let isCharging: Bool?
    let hasBattery: Bool
    let powerSaverActive: Bool
    let source: String
    let error: String?
}
```

- [ ] **Step 5: Add battery runtime state**

Inside `CodexGaugeApp`, near the existing timers and status properties, add:

```swift
    private var batteryStatus: BatteryStatus?
    private var batteryTimer: Timer?
    private var batteryRunLoopSource: CFRunLoopSource?
```

Near the existing interval constants, add:

```swift
    private let batterySampleInterval: TimeInterval = 60
```

In `applicationDidFinishLaunching`, after `registerDefaultPreferences()` and before loading historical samples, add:

```swift
        sampleBattery()
        startBatterySampler()
```

In `applicationWillTerminate`, add:

```swift
        batteryTimer?.invalidate()
        if let batteryRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), batteryRunLoopSource, .commonModes)
        }
```

- [ ] **Step 6: Implement the native battery reader and sampler**

Add these methods near the existing system metric sampling methods in `native/CodexGauge.swift`:

```swift
    private func startBatterySampler() {
        batteryTimer?.invalidate()
        let nextTimer = Timer(timeInterval: batterySampleInterval, repeats: true) { [weak self] _ in
            self?.sampleBattery()
        }
        batteryTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
        startPowerSourceNotifications()
    }

    private func startPowerSourceNotifications() {
        guard batteryRunLoopSource == nil else {
            return
        }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else {
                return
            }
            let app = Unmanaged<CodexGaugeApp>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                app.handlePowerSourceChanged()
            }
        }, context)?.takeRetainedValue() else {
            appendLog("battery power source notification unavailable")
            return
        }
        batteryRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func handlePowerSourceChanged() {
        sampleBattery()
        scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
        configureHardwareSamplersForPowerState()
        rebuildMenu()
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
        refreshSignalPopoverIfNeeded()
    }

    private func sampleBattery() {
        batteryStatus = readBatteryStatus()
    }

    private func readBatteryStatus() -> BatteryStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryStatus(percent: nil, isPluggedIn: nil, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: "Power source info unavailable")
        }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef], !sources.isEmpty else {
            return BatteryStatus(percent: nil, isPluggedIn: true, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: nil)
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let type = description[kIOPSTypeKey as String] as? String,
                type == kIOPSInternalBatteryType
            else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let maximum = description[kIOPSMaxCapacityKey as String] as? Int
            let state = description[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool
            let percent = batteryPercent(current: current, maximum: maximum)
            let pluggedIn = state == kIOPSACPowerValue ? true : (state == kIOPSBatteryPowerValue ? false : nil)
            let active = pluggedIn == false
            return BatteryStatus(percent: percent, isPluggedIn: pluggedIn, isCharging: isCharging, hasBattery: true, powerSaverActive: active, source: "IOPS", error: nil)
        }

        return BatteryStatus(percent: nil, isPluggedIn: true, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: nil)
    }

    private func batteryPercent(current: Int?, maximum: Int?) -> Int? {
        guard let current, let maximum, maximum > 0 else {
            return nil
        }
        let value = Int(round(Double(current) * 100.0 / Double(maximum)))
        return max(0, min(100, value))
    }
```

- [ ] **Step 7: Run the focused test and verify it passes**

Run:

```bash
python3 -m unittest tests.test_native_hardening.NativeHardeningTests.test_battery_status_uses_native_iops_without_persisting_history -v
```

Expected: `OK`.

- [ ] **Step 8: Build to catch Swift/IOKit issues**

Run:

```bash
./script/build_and_run.sh --build-only
```

Expected: app bundle builds successfully. If Swift reports CoreFoundation bridging errors, fix only the affected IOPS casts while preserving the tested method names and tokens.

- [ ] **Step 9: Commit**

Run:

```bash
git add tests/test_native_hardening.py native/CodexGauge.swift script/build_and_run.sh
git commit -m "feat: add native battery status reader"
```

---

### Task 2: Power Saver Refresh Policy

**Files:**
- Modify: `tests/test_native_hardening.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write the failing Power Saver policy test**

Add this test method to `tests/test_native_hardening.py`:

```python
    def test_power_saver_refresh_policy_overrides_background_refresh_on_battery(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private let powerSaverHealthyRefreshInterval: TimeInterval = 20 * 60",
            "private let powerSaverLowRefreshInterval: TimeInterval = 10 * 60",
            "private let powerSaverCriticalRefreshInterval: TimeInterval = 5 * 60",
            "private func powerSaverActive() -> Bool",
            "batteryStatus?.powerSaverActive == true",
            "private func powerSaverRefreshInterval(for status: ServiceStatus?) -> TimeInterval",
            "return powerSaverCriticalRefreshInterval",
            "return powerSaverLowRefreshInterval",
            "return powerSaverHealthyRefreshInterval",
            "if powerSaverActive() {",
            "return powerSaverRefreshInterval(for: status)",
            "if let interval = fixedRefreshInterval()",
            "scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))",
        ]:
            self.assertIn(token, source)

        next_refresh_body = source.split("private func nextRefreshInterval(for status: ServiceStatus?)", 1)[1].split("private func nextRefreshCountdownText", 1)[0]
        self.assertLess(
            next_refresh_body.index("if powerSaverActive() {"),
            next_refresh_body.index("if let interval = fixedRefreshInterval()"),
        )
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_native_hardening.NativeHardeningTests.test_power_saver_refresh_policy_overrides_background_refresh_on_battery -v
```

Expected: `FAIL` because Power Saver intervals and helpers do not exist yet.

- [ ] **Step 3: Add Power Saver refresh constants**

In `CodexGaugeApp`, near the existing refresh interval constants, add:

```swift
    private let powerSaverHealthyRefreshInterval: TimeInterval = 20 * 60
    private let powerSaverLowRefreshInterval: TimeInterval = 10 * 60
    private let powerSaverCriticalRefreshInterval: TimeInterval = 5 * 60
```

- [ ] **Step 4: Add Power Saver policy helpers**

Near `nextRefreshInterval(for:)`, add:

```swift
    private func powerSaverActive() -> Bool {
        batteryStatus?.powerSaverActive == true
    }

    private func powerSaverRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        guard let status, status.ok else {
            return powerSaverCriticalRefreshInterval
        }
        guard let lowest = minQuota(status.fiveHourLeft, status.sevenDayLeft) else {
            return powerSaverCriticalRefreshInterval
        }
        if lowest < 10 {
            return powerSaverCriticalRefreshInterval
        }
        if lowest <= 40 {
            return powerSaverLowRefreshInterval
        }
        return powerSaverHealthyRefreshInterval
    }
```

- [ ] **Step 5: Route refresh scheduling through Power Saver before fixed preferences**

Change `nextRefreshInterval(for:)` to:

```swift
    private func nextRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        if powerSaverActive() {
            return powerSaverRefreshInterval(for: status)
        }
        guard let status, status.ok else {
            return failureRefreshInterval
        }
        if let interval = fixedRefreshInterval() {
            return interval
        }
        guard let lowest = minQuota(status.fiveHourLeft, status.sevenDayLeft) else {
            return failureRefreshInterval
        }
        if lowest < 10 {
            return criticalRefreshInterval
        }
        if lowest <= 40 {
            return watchRefreshInterval
        }
        return normalRefreshInterval
    }
```

- [ ] **Step 6: Run the focused test and verify it passes**

Run:

```bash
python3 -m unittest tests.test_native_hardening.NativeHardeningTests.test_power_saver_refresh_policy_overrides_background_refresh_on_battery -v
```

Expected: `OK`.

- [ ] **Step 7: Run the existing adaptive refresh test**

Run:

```bash
python3 -m unittest tests.test_native_hardening.NativeHardeningTests.test_native_app_shows_reset_timing_and_adaptive_refresh -v
```

Expected: `OK`.

- [ ] **Step 8: Commit**

Run:

```bash
git add tests/test_native_hardening.py native/CodexGauge.swift
git commit -m "feat: add battery power saver refresh policy"
```

---

### Task 3: Throttle Hardware Sampling on Battery

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write the failing sampler throttling test**

Add this test method to `tests/test_signal_console_ux.py`:

```python
    def test_power_saver_pauses_background_hardware_sampling_on_battery(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private var temporaryHardwareSamplerTimer: Timer?",
            "private let powerSaverHardwareSampleInterval: TimeInterval = 10",
            "configureHardwareSamplersForPowerState()",
            "private func configureHardwareSamplersForPowerState()",
            "private func hardwareBackgroundSamplingAllowed() -> Bool",
            "return !powerSaverActive()",
            "private func startTemporaryHardwareSamplerIfNeeded()",
            "Timer(timeInterval: powerSaverHardwareSampleInterval, repeats: true)",
            "sampleHardwareForOpenSignalConsole()",
            "private func sampleHardwareForOpenSignalConsole()",
            "sampleTemperature()",
            "sampleSystemMetrics()",
            "private func stopTemporaryHardwareSampler()",
            "temporaryHardwareSamplerTimer?.invalidate()",
            "startTemporaryHardwareSamplerIfNeeded()",
            "stopTemporaryHardwareSampler()",
        ]:
            self.assertIn(token, source)

        launch_body = source.split("func applicationDidFinishLaunching", 1)[1].split("func applicationWillTerminate", 1)[0]
        self.assertIn("configureHardwareSamplersForPowerState()", launch_body)
        self.assertNotIn("startTemperatureSampler()", launch_body)
        self.assertNotIn("startSystemMetricsSampler()", launch_body)

        configure_body = source.split("private func configureHardwareSamplersForPowerState()", 1)[1].split("private func hardwareBackgroundSamplingAllowed", 1)[0]
        self.assertIn("if hardwareBackgroundSamplingAllowed()", configure_body)
        self.assertIn("startTemperatureSampler()", configure_body)
        self.assertIn("startSystemMetricsSampler()", configure_body)
        self.assertIn("temperatureTimer?.invalidate()", configure_body)
        self.assertIn("systemMetricsTimer?.invalidate()", configure_body)
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_power_saver_pauses_background_hardware_sampling_on_battery -v
```

Expected: `FAIL` because sampler policy helpers do not exist yet.

- [ ] **Step 3: Add temporary sampler state and interval**

In `CodexGaugeApp`, near existing timer properties, add:

```swift
    private var temporaryHardwareSamplerTimer: Timer?
```

Near existing sampling intervals, add:

```swift
    private let powerSaverHardwareSampleInterval: TimeInterval = 10
```

In `applicationWillTerminate`, add:

```swift
        temporaryHardwareSamplerTimer?.invalidate()
```

- [ ] **Step 4: Replace unconditional hardware sampler startup**

In `applicationDidFinishLaunching`, replace:

```swift
        startTemperatureSampler()
        startSystemMetricsSampler()
```

with:

```swift
        configureHardwareSamplersForPowerState()
```

- [ ] **Step 5: Add sampler policy helpers**

Add these methods near `startTemperatureSampler()`:

```swift
    private func configureHardwareSamplersForPowerState() {
        if hardwareBackgroundSamplingAllowed() {
            startTemperatureSampler()
            startSystemMetricsSampler()
            stopTemporaryHardwareSampler()
            return
        }
        temperatureTimer?.invalidate()
        temperatureTimer = nil
        systemMetricsTimer?.invalidate()
        systemMetricsTimer = nil
        startTemporaryHardwareSamplerIfNeeded()
    }

    private func hardwareBackgroundSamplingAllowed() -> Bool {
        return !powerSaverActive()
    }

    private func startTemporaryHardwareSamplerIfNeeded() {
        guard powerSaverActive(), signalPopover?.isShown == true else {
            stopTemporaryHardwareSampler()
            return
        }
        guard temporaryHardwareSamplerTimer == nil else {
            return
        }
        sampleHardwareForOpenSignalConsole()
        let nextTimer = Timer(timeInterval: powerSaverHardwareSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleHardwareForOpenSignalConsole()
        }
        temporaryHardwareSamplerTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func sampleHardwareForOpenSignalConsole() {
        sampleTemperature()
        sampleSystemMetrics()
    }

    private func stopTemporaryHardwareSampler() {
        temporaryHardwareSamplerTimer?.invalidate()
        temporaryHardwareSamplerTimer = nil
    }
```

- [ ] **Step 6: Wire temporary sampling to Signal Console open and close**

In `showSignalConsolePopover()`, after `startPopoverCountdownTimer()`, add:

```swift
        startTemporaryHardwareSamplerIfNeeded()
```

In `toggleSignalConsole(_:)`, inside the branch that closes an already-open popover, add:

```swift
            stopTemporaryHardwareSampler()
```

In `startPopoverCountdownTimer()`, in the branch where the popover is no longer shown, add:

```swift
                self.stopTemporaryHardwareSampler()
```

In `handlePowerSourceChanged()`, keep the call to:

```swift
        configureHardwareSamplersForPowerState()
```

- [ ] **Step 7: Run the focused test and verify it passes**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_power_saver_pauses_background_hardware_sampling_on_battery -v
```

Expected: `OK`.

- [ ] **Step 8: Run existing sampler tests**

Run:

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_system_metrics_sample_every_five_seconds_and_are_bounded \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_ssd_temperature_display_keeps_last_valid_read_briefly \
  tests.test_native_hardening.NativeHardeningTests.test_system_metric_history_is_local_bounded_and_clearable \
  -v
```

Expected: `OK`. If tests fail because they expect unconditional startup, update the assertions to expect startup through `configureHardwareSamplersForPowerState()`, while keeping the existing 1-second and 5-second plugged-in samplers intact.

- [ ] **Step 9: Commit**

Run:

```bash
git add tests/test_signal_console_ux.py native/CodexGauge.swift
git commit -m "feat: throttle hardware sampling on battery"
```

---

### Task 4: Battery Menu Bar, Signal Console, Diagnostics, and Setup Doctor

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write the failing UI coverage test**

Add this test method to `tests/test_signal_console_ux.py`:

```python
    def test_battery_signal_appears_in_menu_bar_console_diagnostics_and_doctor(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "batteryStatusText: String",
            "powerSaverText: String",
            "refreshCadenceText: String",
            "batteryStatusText(status: batteryStatus)",
            "powerSaverStatusText()",
            "refreshCadenceStatusText()",
            "batteryStatus: batteryStatus",
            "drawBatteryStatusRow(in: card)",
            "drawMenuBarBattery(status: batteryStatus, rect: menuBarBatteryRect, palette: palette)",
            "private let menuBarBatteryRect",
            "private func drawMenuBarBattery",
            "drawMenuBarBatteryTerminal",
            "drawMenuBarBatteryFill",
            "private func batteryMenuBarColor",
            "private func batteryDisplayText",
            "Battery",
            "Power Saver",
            "batteryDoctorCheck(batteryStatus)",
            "Battery state: \\(batteryDiagnosticsText())",
            "Power Saver state: \\(powerSaverStatusText())",
            "parts.append(\"Battery \\(batteryDisplayText(batteryStatus))\")",
        ]:
            self.assertIn(token, source)

        make_status_signature = source.split("private func makeStatusImage(", 1)[1].split(") -> NSImage", 1)[0]
        self.assertIn("batteryStatus: BatteryStatus?", make_status_signature)
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_battery_signal_appears_in_menu_bar_console_diagnostics_and_doctor -v
```

Expected: `FAIL` because no UI battery fields exist yet.

- [ ] **Step 3: Extend the Signal Console model**

Add these properties to `SignalConsoleModel` after `ramUsageText`:

```swift
    let batteryStatusText: String
    let powerSaverText: String
    let refreshCadenceText: String
```

Update every `SignalConsoleModel(...)` construction, including previews, to pass:

```swift
                batteryStatusText: batteryStatusText(status: batteryStatus),
                powerSaverText: powerSaverStatusText(),
                refreshCadenceText: refreshCadenceStatusText(),
```

For preview models, use deterministic strings:

```swift
        batteryStatusText: unavailable ? "Battery --" : "Battery 74%",
        powerSaverText: unavailable ? "Power Saver unknown" : "Power Saver active",
        refreshCadenceText: unavailable ? "Refresh --" : "Refresh 20m",
```

- [ ] **Step 4: Draw a compact battery row in Signal Console**

In `drawTrendSection()`, after `drawTemperatureMovementRow(in: card)`, add:

```swift
        drawBatteryStatusRow(in: card)
```

Add this method near other Movement drawing methods:

```swift
    private func drawBatteryStatusRow(in card: NSRect) {
        let row = NSRect(x: card.minX + 16, y: card.maxY - 62, width: card.width - 32, height: 18)
        let color = model.powerSaverText.contains("active") ? amberAccent : textSecondary
        drawText("Battery", x: row.minX, y: row.minY + 1, width: 54, height: 12, size: 8.6, weight: .bold, color: color)
        drawText(model.batteryStatusText, x: row.minX + 68, y: row.minY + 1, width: 92, height: 12, size: 8.6, weight: .semibold, color: textPrimary, mono: true)
        drawText(model.powerSaverText, x: row.minX + 168, y: row.minY + 1, width: 116, height: 12, size: 8.2, weight: .medium, color: color)
        drawText(model.refreshCadenceText, x: row.maxX - 82, y: row.minY + 1, width: 82, height: 12, size: 8.2, weight: .medium, color: textMuted, mono: true)
    }
```

If the battery row visually collides with SSD temperature in the rendered fixture, reduce row height and y offsets rather than increasing `signalPopoverSize`.

- [ ] **Step 5: Add battery text helpers**

Add these helpers near the SSD/system metric display helpers:

```swift
    private func batteryStatusText(status: BatteryStatus?) -> String {
        guard let status, status.hasBattery else {
            return "Battery --"
        }
        guard let percent = status.percent else {
            return "Battery --"
        }
        return "Battery \(percent)%"
    }

    private func powerSaverStatusText() -> String {
        powerSaverActive() ? "Power Saver active" : "Power Saver off"
    }

    private func refreshCadenceStatusText() -> String {
        let interval = nextRefreshInterval(for: snapshot?.codex)
        let minutes = Int(round(interval / 60.0))
        return "Refresh \(minutes)m"
    }

    private func batteryDisplayText(_ status: BatteryStatus?) -> String {
        guard let status, status.hasBattery, let percent = status.percent else {
            return "--"
        }
        return "\(percent)%"
    }
```

- [ ] **Step 6: Add the menu-bar battery glyph**

Near existing menu bar geometry constants, add:

```swift
    private let menuBarBatteryRect = NSRect(x: 170, y: 4.2, width: 28, height: 13.8)
```

If this overlaps the current CPU/RAM strip, move `menuBarSystemMetricStripRect` to the right and increase `statusItemWidth`/`statusImageSize` by the minimum needed amount.

Change the `makeStatusImage` signature to include battery status:

```swift
    private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage {
```

Update every `makeStatusImage(...)` call to pass:

```swift
            batteryStatus: batteryStatus
```

In `makeStatusImage`, after the SSD temperature chip and before or after the CPU/RAM strip, add:

```swift
        drawMenuBarBattery(status: batteryStatus, rect: menuBarBatteryRect, palette: palette)
```

Add these drawing helpers near `drawMenuBarSystemMetricStrip`:

```swift
    private func drawMenuBarBattery(status: BatteryStatus?, rect: NSRect, palette: GaugePalette) {
        guard status?.hasBattery == true else {
            return
        }
        let color = batteryMenuBarColor(status, palette: palette)
        let shell = NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 1.2), xRadius: 3.0, yRadius: 3.0)
        color.withAlphaComponent(status?.isPluggedIn == true ? 0.22 : 0.36).setFill()
        shell.fill()
        color.withAlphaComponent(0.72).setStroke()
        shell.lineWidth = 0.7
        shell.stroke()
        drawMenuBarBatteryTerminal(rect: rect, color: color)
        drawMenuBarBatteryFill(status: status, rect: rect.insetBy(dx: 3.1, dy: 3.7), color: color)
    }

    private func drawMenuBarBatteryTerminal(rect: NSRect, color: NSColor) {
        let terminal = NSBezierPath(roundedRect: NSRect(x: rect.maxX - 1.1, y: rect.midY - 2.8, width: 2.6, height: 5.6), xRadius: 1.1, yRadius: 1.1)
        color.withAlphaComponent(0.72).setFill()
        terminal.fill()
    }

    private func drawMenuBarBatteryFill(status: BatteryStatus?, rect: NSRect, color: NSColor) {
        guard let percent = status?.percent else {
            return
        }
        let fillWidth = max(1.0, rect.width * CGFloat(max(0, min(100, percent))) / 100.0)
        let fill = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height), xRadius: 1.8, yRadius: 1.8)
        color.withAlphaComponent(0.88).setFill()
        fill.fill()
    }

    private func batteryMenuBarColor(_ status: BatteryStatus?, palette: GaugePalette) -> NSColor {
        guard let status, status.hasBattery else {
            return palette.mutedText
        }
        guard let percent = status.percent else {
            return palette.mutedText
        }
        if percent < 15 {
            return criticalQuotaColor
        }
        if percent < 30 {
            return warningQuotaColor
        }
        return status.powerSaverActive ? warningQuotaColor : normalQuotaColor
    }
```

- [ ] **Step 7: Add battery to tooltip/accessibility**

In `statusTooltipTitle(_:)`, `menuBarAccessibilitySummary(...)`, or whichever helper builds the tooltip text, add:

```swift
        parts.append("Battery \(batteryDisplayText(batteryStatus))")
```

Keep the existing `parts.append("SSD ...")`, `CPU`, and `RAM` entries.

- [ ] **Step 8: Add Setup Doctor and diagnostics**

In `runSetupDoctorChecks()`, append:

```swift
            batteryDoctorCheck(batteryStatus),
```

Add:

```swift
    private func batteryDoctorCheck(_ status: BatteryStatus?) -> DoctorCheck {
        guard let status else {
            return DoctorCheck(title: "Battery", state: "grey", detail: "Battery state unavailable")
        }
        guard status.hasBattery else {
            return DoctorCheck(title: "Battery", state: "grey", detail: "No internal battery")
        }
        let detail = "\(batteryDisplayText(status)) · \(status.powerSaverActive ? "Power Saver active" : "plugged in")"
        if let percent = status.percent, percent < 15 {
            return DoctorCheck(title: "Battery", state: "red", detail: detail)
        }
        if status.powerSaverActive {
            return DoctorCheck(title: "Battery", state: "amber", detail: detail)
        }
        return DoctorCheck(title: "Battery", state: "green", detail: detail)
    }

    private func batteryDiagnosticsText() -> String {
        guard let batteryStatus else {
            return "unavailable"
        }
        guard batteryStatus.hasBattery else {
            return "no internal battery"
        }
        let power = batteryStatus.powerSaverActive ? "on battery" : "plugged in"
        return "\(batteryDisplayText(batteryStatus)), \(power)"
    }
```

In `safeDiagnosticsText()`, add these lines before `Refresh mode`:

```swift
            "Battery state: \(batteryDiagnosticsText())",
            "Power Saver state: \(powerSaverStatusText())",
```

- [ ] **Step 9: Run the focused UI test and verify it passes**

Run:

```bash
python3 -m unittest tests.test_signal_console_ux.SignalConsoleUXTests.test_battery_signal_appears_in_menu_bar_console_diagnostics_and_doctor -v
```

Expected: `OK`.

- [ ] **Step 10: Run existing menu bar and console tests**

Run:

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_integrates_ssd_temperature_without_removing_current_quota_info \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_and_signal_console_show_cpu_ram_signals \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_signal_console_previews_derive_health_summary_from_visible_checks \
  -v
```

Expected: `OK`. If layout constants change, update tests to assert the new battery-aware constants and verify quota, reset, SSD temperature, CPU, and RAM tokens still exist.

- [ ] **Step 11: Build**

Run:

```bash
./script/build_and_run.sh --build-only
```

Expected: build succeeds.

- [ ] **Step 12: Commit**

Run:

```bash
git add tests/test_signal_console_ux.py native/CodexGauge.swift
git commit -m "feat: show battery power saver status"
```

---

### Task 5: Public Documentation and Privacy Copy

**Files:**
- Modify: `tests/test_public_readme_package.py`
- Modify: `tests/test_native_hardening.py`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/PRIVACY.md`

- [ ] **Step 1: Write failing public docs tests**

In `tests/test_public_readme_package.py`, extend `test_readme_explains_why_it_is_different` by adding these phrases to the existing `for phrase in [...]` list:

```python
            "native battery signal",
            "Power Saver on battery",
            "20 minutes normally on battery",
```

In `tests/test_native_hardening.py`, extend `test_system_metric_history_is_local_bounded_and_clearable` or add a new privacy docs test:

```python
    def test_privacy_docs_describe_battery_as_local_hardware_telemetry(self):
        privacy = pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8")

        self.assertIn("battery percentage and power-source state", privacy)
        self.assertIn("Power Saver", privacy)
        self.assertIn("does not store battery history", privacy)
        self.assertNotIn("Battery-history", privacy)
```

- [ ] **Step 2: Run the docs tests and verify they fail**

Run:

```bash
python3 -m unittest \
  tests.test_public_readme_package.PublicReadmePackageTests.test_readme_explains_why_it_is_different \
  tests.test_native_hardening.NativeHardeningTests.test_privacy_docs_describe_battery_as_local_hardware_telemetry \
  -v
```

Expected: `FAIL` because docs do not mention battery Power Saver yet.

- [ ] **Step 3: Update README.md**

Add concise bullets near the CPU/RAM feature bullets:

```markdown
- Native battery signal shows local charge and power-source state with a familiar battery glyph
  原生电池信号会用熟悉的电池图形显示本机电量和供电状态
- Power Saver on battery slows quota refresh to 20 minutes normally on battery, 10 minutes when low, and 5 minutes when critical, while pausing background hardware history sampling until Signal Console is open
  电池供电时 Power Saver 会把额度刷新降低到通常 20 分钟、额度偏低 10 分钟、严重偏低 5 分钟，并暂停后台硬件历史采样，直到打开 Signal Console
```

Add a row to the “Why Codex Gauge is different” table:

```markdown
| Battery Power Saver | Native battery glyph plus automatic on-battery Power Saver that keeps quota useful while reducing background hardware sampling |
```

Add a privacy/safety line near the CPU/RAM paragraph:

```markdown
Battery display is local battery percentage and power-source state only. Codex Gauge does not store battery history.
```

- [ ] **Step 4: Update README.zh-CN.md**

Add matching Chinese bullets near the CPU/RAM bullets:

```markdown
- 原生电池信号会用熟悉的电池图形显示本机电量和供电状态
- 电池供电时 Power Saver 会把额度刷新降低到通常 20 分钟、额度偏低 10 分钟、严重偏低 5 分钟，并暂停后台硬件历史采样，直到打开 Signal Console
```

Add a table row:

```markdown
| 电池 Power Saver | 原生电池图形加自动电池供电省电模式，在保持额度可用的同时减少后台硬件采样 |
```

- [ ] **Step 5: Update docs/PRIVACY.md**

Add a bullet to the list of local behavior:

```markdown
- reads local battery percentage and power-source state through macOS power-source APIs for the menu bar battery glyph and automatic Power Saver;
```

Add this paragraph near the CPU/RAM privacy text:

```markdown
Battery state is local hardware telemetry only: current battery percentage, whether external power is connected, and whether Power Saver is active. Codex Gauge does not store battery history.
```

- [ ] **Step 6: Run the docs tests and verify they pass**

Run:

```bash
python3 -m unittest \
  tests.test_public_readme_package.PublicReadmePackageTests.test_readme_explains_why_it_is_different \
  tests.test_native_hardening.NativeHardeningTests.test_privacy_docs_describe_battery_as_local_hardware_telemetry \
  -v
```

Expected: `OK`.

- [ ] **Step 7: Commit**

Run:

```bash
git add tests/test_public_readme_package.py tests/test_native_hardening.py README.md README.zh-CN.md docs/PRIVACY.md
git commit -m "docs: document battery power saver"
```

---

### Task 6: Final Verification and Install

**Files:**
- Modify only if verification exposes a real issue: `native/CodexGauge.swift`, tests, or docs touched above.

- [ ] **Step 1: Run the full unit test suite**

Run:

```bash
python3 -m unittest discover -s tests -v
```

Expected: all tests pass.

- [ ] **Step 2: Run shell syntax checks**

Run:

```bash
bash -n install.sh
bash -n script/build_and_run.sh
bash -n script/package_release.sh
bash -n script/release_check.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Build the native app**

Run:

```bash
./script/build_and_run.sh --build-only
```

Expected: `native/dist/CodexGauge.app` is rebuilt and codesign verification passes.

- [ ] **Step 4: Inspect bundle metadata**

Run:

```bash
plutil -p native/dist/CodexGauge.app/Contents/Info.plist
```

Expected: bundle metadata still includes `CFBundleShortVersionString`, `CodexGaugeUsagePath`, and no source checkout paths.

- [ ] **Step 5: Install locally**

Run:

```bash
bash install.sh
```

Expected: `/Applications/CodexGauge.app` is replaced and the LaunchAgent starts.

- [ ] **Step 6: Verify installed LaunchAgent**

Run:

```bash
launchctl print "gui/$(id -u)/app.codexgauge.menubar"
pgrep -fl 'CodexGauge|Codex Gauge'
```

Expected: LaunchAgent state is `running`, and a `CodexGauge-bin` process exists.

- [ ] **Step 7: Check launch logs**

Run:

```bash
wc -c "$HOME/Library/Application Support/CodexGauge/launchd.err.log" "$HOME/Library/Application Support/CodexGauge/launchd.out.log" 2>/dev/null || true
tail -n 80 "$HOME/Library/Application Support/CodexGauge/launchd.err.log" 2>/dev/null || true
```

Expected: no startup errors. Empty logs are acceptable.

- [ ] **Step 8: Commit any verification fixes**

If verification required code or test fixes, commit them:

```bash
git add native/CodexGauge.swift tests README.md README.zh-CN.md docs/PRIVACY.md script/build_and_run.sh
git commit -m "fix: verify battery power saver"
```

Expected: commit is created only if files changed during final verification.
