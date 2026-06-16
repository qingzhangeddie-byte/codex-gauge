# CPU and RAM Signal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local CPU and RAM percentages to the menu bar and Signal Console without removing existing quota, reset, or SSD temperature signals.

**Architecture:** Add a bounded `SystemMetricSample` model and 5-second AppKit timer inside `CodexGaugeApp`. Use host CPU load and VM statistics from local macOS APIs, expose a 10-minute graph slice through `SignalConsoleModel`, store 24 hours of local metric samples, and draw compact CPU/RAM signals in the existing menu bar and Movement card.

**Tech Stack:** Swift/AppKit native menu bar app, Darwin/Mach host APIs, Python unittest source assertions, existing fixture renderer and release scripts.

---

## File Structure

- Modify `native/CodexGauge.swift`
  - Add `SystemMetricSample`.
  - Add system metrics timer/state/storage.
  - Add CPU/RAM local sampling helpers.
  - Extend `SignalConsoleModel`.
  - Draw menu-bar CPU/RAM strip.
  - Draw Signal Console CPU/RAM mini metrics and sparklines.
- Modify `tests/test_signal_console_ux.py`
  - Add source-level tests for sampler, model fields, menu-bar strip, and Movement rendering.
- Modify `tests/test_native_hardening.py`
  - Add local-only, bounded, clearable storage assertions.
- Modify `tests/test_public_readme_package.py`
  - Add README expectations.
- Modify `README.md` and `README.zh-CN.md`
  - Document local CPU/RAM metrics.
- Regenerate `docs/design/app-rendered-signal-console/*.png` and `docs/assets/*.png`.

---

### Task 1: System Metrics Sampler and Storage

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `tests/test_native_hardening.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write failing tests**

Add source assertions for:

```python
    def test_system_metrics_sample_every_five_seconds_and_are_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct SystemMetricSample: Codable", source)
        self.assertIn("private var systemMetricsTimer: Timer?", source)
        self.assertIn("private var systemMetricSamples: [SystemMetricSample] = []", source)
        self.assertIn("private let systemMetricSampleInterval: TimeInterval = 5", source)
        self.assertIn("private let systemMetricGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("private let systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("private let maxSystemMetricSamples = 24 * 60 * 60 / 5", source)
        self.assertIn('systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"', source)
        self.assertIn("startSystemMetricsSampler()", source)
        self.assertIn("sampleSystemMetrics()", source)
        self.assertIn("Timer(timeInterval: systemMetricSampleInterval, repeats: true)", source)
        self.assertIn("readSystemMetrics()", source)
        self.assertIn("readCPUUsagePercent()", source)
        self.assertIn("readRAMUsagePercent()", source)
        self.assertIn("host_statistics", source)
        self.assertIn("host_processor_info", source)
        self.assertIn("retainedSystemMetricSamples", source)
        self.assertIn("systemMetricGraphSamples", source)
        self.assertIn("writeSystemMetricSamples", source)
        self.assertIn("readSystemMetricSamples", source)
```

Add hardening assertions:

```python
        self.assertIn('systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"', source)
        self.assertIn("systemMetricsHistoryPath", source)
        self.assertIn("systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("maxSystemMetricSamples = 24 * 60 * 60 / 5", source)
        self.assertIn("systemMetricsHistoryPath,", source)
        self.assertNotIn("Keychain", source[source.find("private func appendSystemMetricSample"):source.find("private func readSystemMetricSamples")])
```

- [ ] **Step 2: Run tests and verify they fail**

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_system_metrics_sample_every_five_seconds_and_are_bounded \
  tests.test_native_hardening.NativeHardeningTests.test_temperature_history_is_local_bounded_and_clearable \
  -v
```

Expected: FAIL because system metrics do not exist yet.

- [ ] **Step 3: Implement sampler and bounded storage**

Add `SystemMetricSample` near `TemperatureSample`:

```swift
private struct SystemMetricSample: Codable {
    let time: String
    let cpuPercent: Int?
    let ramPercent: Int?
    let ok: Bool
}
```

Add app state/constants:

```swift
    private var systemMetricsTimer: Timer?
    private var systemMetricSamples: [SystemMetricSample] = []
    private var lastCPUTicks: [UInt32]?
    private let systemMetricSampleInterval: TimeInterval = 5
    private let systemMetricGraphWindow: TimeInterval = 10 * 60
    private let systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60
    private let maxSystemMetricSamples = 24 * 60 * 60 / 5
    private let systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"
```

Add path:

```swift
    private lazy var systemMetricsHistoryPath = "\(supportDir)/\(systemMetricsHistoryFileName)"
```

Load/start in `applicationDidFinishLaunching`:

```swift
        systemMetricSamples = readSystemMetricSamples()
        startSystemMetricsSampler()
```

Stop in `applicationWillTerminate`:

```swift
        systemMetricsTimer?.invalidate()
        writeSystemMetricSamples(systemMetricSamples)
```

Add sampler/storage helpers near temperature helpers:

```swift
    private func startSystemMetricsSampler() {
        systemMetricsTimer?.invalidate()
        sampleSystemMetrics()
        let nextTimer = Timer(timeInterval: systemMetricSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleSystemMetrics()
        }
        systemMetricsTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func sampleSystemMetrics() {
        let metrics = readSystemMetrics()
        appendSystemMetricSample(metrics)
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
    }

    private func readSystemMetrics() -> (cpu: Int?, ram: Int?) {
        (readCPUUsagePercent(), readRAMUsagePercent())
    }
```

Use `host_processor_info` to compute CPU deltas from `lastCPUTicks`; use `host_statistics` VM page counts for RAM percent.

- [ ] **Step 4: Run focused tests**

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_system_metrics_sample_every_five_seconds_and_are_bounded \
  tests.test_native_hardening.NativeHardeningTests.test_temperature_history_is_local_bounded_and_clearable \
  -v
```

Expected: PASS.

---

### Task 2: Menu Bar and Signal Console UI

**Files:**
- Modify: `tests/test_signal_console_ux.py`
- Modify: `native/CodexGauge.swift`

- [ ] **Step 1: Write failing UI tests**

Add assertions:

```python
    def test_menu_bar_shows_compact_cpu_ram_strip_without_removing_existing_signals(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("systemMetricSampleForDisplay()", source)
        self.assertIn("drawMenuBarSystemMetricStrip", source)
        self.assertIn('"C\\(cpu)"', source)
        self.assertIn('"R\\(ram)"', source)
        self.assertIn("drawPlanBRow(window: \"5h\"", source)
        self.assertIn("drawPlanBRow(window: \"7d\"", source)
        self.assertIn("drawMenuBarSSDTemperature", source)
```

```python
    def test_signal_console_movement_shows_cpu_ram_metrics(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("systemMetricHistory: [SystemMetricSample]", source)
        self.assertIn("cpuUsageText: String", source)
        self.assertIn("ramUsageText: String", source)
        self.assertIn("drawSystemMetricMovementRows", source)
        self.assertIn('"CPU"', source)
        self.assertIn('"RAM"', source)
        self.assertIn('"last 10m"', source)
        self.assertIn("drawSystemMetricSparkline", source)
        self.assertIn("systemMetricPressureColor", source)
```

- [ ] **Step 2: Run UI tests and verify they fail**

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_shows_compact_cpu_ram_strip_without_removing_existing_signals \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_signal_console_movement_shows_cpu_ram_metrics \
  -v
```

Expected: FAIL.

- [ ] **Step 3: Implement UI model and drawing**

Extend `SignalConsoleModel`:

```swift
    let systemMetricHistory: [SystemMetricSample]
    let cpuUsageText: String
    let ramUsageText: String
```

Pass `systemMetricGraphSamples(systemMetricSamples)` through both model branches.

Add menu-bar drawing:

```swift
    private func drawMenuBarSystemMetricStrip(sample: SystemMetricSample?, palette: GaugePalette) {
        // Draw tiny C/R monospaced values without removing existing rows.
    }
```

Add Signal Console movement rows:

```swift
    private func drawSystemMetricMovementRows(in card: NSRect) {
        // Draw CPU and RAM labels, values, and compact sparklines under SSD temp.
    }
```

- [ ] **Step 4: Run UI tests**

```bash
python3 -m unittest \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_menu_bar_shows_compact_cpu_ram_strip_without_removing_existing_signals \
  tests.test_signal_console_ux.SignalConsoleUXTests.test_signal_console_movement_shows_cpu_ram_metrics \
  -v
```

Expected: PASS.

---

### Task 3: Docs, Assets, Install, Commit

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `tests/test_public_readme_package.py`
- Regenerate: `docs/design/app-rendered-signal-console/*.png`
- Regenerate: `docs/assets/*.png`

- [ ] **Step 1: Add README tests**

Assert English README includes:

```python
"local CPU and RAM percentages"
"CPU/RAM system strip"
"24-hour local CPU/RAM history"
```

Assert Chinese README includes:

```python
"本地 CPU 和 RAM 百分比"
"CPU/RAM 系统条"
"24 小时本地 CPU/RAM 历史"
```

- [ ] **Step 2: Run README tests and verify they fail**

```bash
python3 -m unittest tests.test_public_readme_package.PublicReadmePackageTests -v
```

Expected: FAIL.

- [ ] **Step 3: Update README copy**

Add concise local-only CPU/RAM bullets near SSD temperature features.

- [ ] **Step 4: Verify, regenerate, install**

```bash
python3 -m unittest discover -s tests
./script/build_and_run.sh --build-only
./native/dist/CodexGauge.app/Contents/MacOS/CodexGauge-bin --render-signal-console-fixtures docs/design/app-rendered-signal-console
swift script/generate_public_assets.swift
./script/release_check.sh
./script/replace_installed_app.sh
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add native/CodexGauge.swift tests README.md README.zh-CN.md docs/assets docs/design/app-rendered-signal-console
git commit -m "feat: add CPU and RAM signals"
```
