import pathlib
import unittest


def native_swift_sources() -> str:
    return "\n".join(
        path.read_text()
        for path in sorted(pathlib.Path("native").glob("CodexGauge*.swift"))
    )


class NativeHardeningTests(unittest.TestCase):
    def test_build_script_bundles_codex_helper_without_checkout_paths(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_RESOURCES="$APP_CONTENTS/Resources"', script)
        self.assertIn('stage_resources="$stage_contents/Resources"', script)
        self.assertIn('cp "$ROOT_DIR/native/codex_status.py" "$stage_resources/codex_status.py"', script)
        self.assertIn('ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"', script)
        self.assertIn('APP_BINARY_NAME="${APP_NAME}-bin"', script)
        self.assertIn('APP_LAUNCHER="$APP_MACOS/$APP_NAME"', script)
        self.assertIn('#!/bin/zsh', script)
        self.assertIn("install_launch_agent", script)
        self.assertIn("app.codexgauge.menubar.plist", script)
        self.assertIn("<key>KeepAlive</key>", script)
        self.assertIn("launchctl bootstrap", script)
        self.assertIn("launchctl kickstart -k", script)
        self.assertNotIn("remove_watchdog", script)
        self.assertNotIn("WATCHDOG", script)
        self.assertIn("CodexGaugePythonPath", script)
        self.assertIn("CodexGaugeUsagePath", script)
        self.assertNotIn("AILimitPythonPath", script)
        self.assertNotIn("AILimitUsagePath", script)
        self.assertNotIn("<string>$ROOT_DIR</string>", script)
        self.assertNotIn("<string>$ROOT_DIR/usage.py</string>", script)
        self.assertNotIn("<string>$VENV_PYTHON</string>", script)

    def test_power_policy_lives_in_focused_swift_unit(self):
        app_source = pathlib.Path("native/CodexGauge.swift").read_text()
        policy_path = pathlib.Path("native/CodexGaugePowerPolicy.swift")
        build_script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertTrue(policy_path.exists())
        policy_source = policy_path.read_text()
        for token in [
            "struct CodexGaugePowerPolicy",
            "let normalRefreshInterval: TimeInterval = 5 * 60",
            "let watchRefreshInterval: TimeInterval = 3 * 60",
            "let criticalRefreshInterval: TimeInterval = 2 * 60",
            "let failureRefreshInterval: TimeInterval = 60",
            "let powerSaverHealthyRefreshInterval: TimeInterval = 20 * 60",
            "let lowBatteryPowerSaverRefreshInterval: TimeInterval = 30 * 60",
            "func hardwareSignalsVisible(powerSaverActive: Bool) -> Bool",
            "func batteryPowerSaverRefreshInterval(percent: Int?) -> TimeInterval?",
            "func powerSaverRefreshInterval(statusOK: Bool, fiveHourLeft: Int?, sevenDayLeft: Int?, batteryPercent: Int?) -> TimeInterval",
            "func nextRefreshInterval(",
        ]:
            self.assertIn(token, policy_source)

        self.assertIn("private let powerPolicy = CodexGaugePowerPolicy()", app_source)
        self.assertIn("powerPolicy.hardwareSignalsVisible(powerSaverActive: powerSaverActive())", app_source)
        self.assertIn("powerPolicy.batteryPowerSaverRefreshInterval(percent: batteryStatus?.percent)", app_source)
        self.assertIn("powerPolicy.nextRefreshInterval(", app_source)
        self.assertIn("SWIFT_SOURCES=(", build_script)
        self.assertIn('"$ROOT_DIR/native/CodexGaugePowerPolicy.swift"', build_script)
        self.assertIn('cp "$SOURCE_FILE" "$BUILD_MAIN"', build_script)
        self.assertIn('"$BUILD_MAIN" "${SUPPORT_SWIFT_SOURCES[@]}"', build_script)

    def test_build_script_bundles_ssd_temperature_helper_without_privileged_tools(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('SSD_TEMPERATURE_SOURCE="$ROOT_DIR/native/ssd_temperature.m"', script)
        self.assertIn('SSD_TEMPERATURE_HELPER="$stage_resources/ssd_temperature"', script)
        self.assertIn('clang "$SSD_TEMPERATURE_SOURCE"', script)
        self.assertIn("-framework Foundation", script)
        self.assertIn("-lIOReport", script)
        self.assertIn('chmod +x "$SSD_TEMPERATURE_HELPER"', script)
        for blocked in ["sudo", "powermetrics", "smartctl", "browser-cookie3", ".codex/auth.json"]:
            self.assertNotIn(blocked, script)

    def test_ssd_temperature_helper_reads_local_ioreport_without_private_user_data(self):
        helper = pathlib.Path("native/ssd_temperature.m")
        self.assertTrue(helper.exists())
        source = helper.read_text()

        for phrase in [
            "IOReportCopyChannelsInGroup",
            "IOReportCreateSamples",
            "IOReportSimpleGetIntegerValue",
            '"ANS2"',
            '"MSP0"',
            '"MSP1"',
            '"Temperature(0)"',
            '"temperature_c"',
            '"ok"',
        ]:
            self.assertIn(phrase, source)
        for blocked in [
            "sudo",
            "powermetrics",
            "smartctl",
            "browser-cookie3",
            ".codex/auth.json",
            "Session file contents",
            "/Users/",
        ]:
            self.assertNotIn(blocked, source)

    def test_temperature_history_is_local_bounded_and_clearable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('temperatureHistoryFileName = "CodexGauge-temperature-history.json"', source)
        self.assertIn("temperatureHistoryPath", source)
        self.assertIn("maxTemperatureSamples = 24 * 60 * 60", source)
        self.assertIn("temperatureGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("temperatureHistoryRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("temperaturePersistInterval: TimeInterval = 60", source)
        self.assertIn("ssdTemperatureReadTimeout", source)
        self.assertIn("Date().addingTimeInterval(ssdTemperatureReadTimeout)", source)
        self.assertIn("process.terminate()", source)
        self.assertIn("retainedTemperatureSamples", source)
        self.assertIn("temperatureHistoryPath,", source)
        self.assertIn("Clear local data", source)

        history_storage = source.split("private func appendTemperatureSample", 1)[1].split("private func readTemperatureSamples", 1)[0]
        self.assertNotIn("Keychain", history_storage)

    def test_system_metric_history_is_local_bounded_and_clearable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"', source)
        self.assertIn("systemMetricsHistoryPath", source)
        self.assertIn("systemMetricSampleInterval: TimeInterval = 5", source)
        self.assertIn("systemMetricGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("systemMetricPersistInterval: TimeInterval = 60", source)
        self.assertIn("lastSystemMetricPersistAt", source)
        self.assertIn("maxSystemMetricSamples = 24 * 60 * 60 / 5", source)
        self.assertIn("systemMetricsHistoryPath,", source)
        self.assertIn("Clear local data", source)
        self.assertIn("CPU/RAM", pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8"))
        self.assertIn("aggregated local CPU and RAM percentages", pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8"))

        metric_storage = source.split("private func appendSystemMetricSample", 1)[1].split("private func readSystemMetricSamples", 1)[0]
        self.assertIn("shouldPersistSystemMetricSamples(now: now)", metric_storage)
        self.assertNotIn("Keychain", metric_storage)
        self.assertNotIn("browser", metric_storage.lower())
        self.assertNotIn("auth.json", metric_storage)

        self.assertIn("private func shouldPersistSystemMetricSamples(now: Date = Date()) -> Bool", source)

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
        notification_handler = source.split("private func handlePowerSourceChanged()", 1)[1].split(
            "private func sampleBattery()", 1
        )[0]
        self.assertNotIn("scheduleNextRefresh(after:", notification_handler)
        self.assertNotIn("pmset", source)
        self.assertNotIn("ioreg", source)
        self.assertNotIn("Battery-history", source)
        self.assertNotIn("batteryHistoryPath", source)
        self.assertNotIn("CodexGauge-battery", source)

    def test_power_saver_refresh_policy_overrides_background_refresh_on_battery(self):
        app_source = pathlib.Path("native/CodexGauge.swift").read_text()
        source = native_swift_sources()

        for token in [
            "let powerSaverHealthyRefreshInterval: TimeInterval = 20 * 60",
            "let powerSaverLowRefreshInterval: TimeInterval = 10 * 60",
            "let powerSaverCriticalRefreshInterval: TimeInterval = 5 * 60",
            "let lowBatteryPowerSaverRefreshInterval: TimeInterval = 30 * 60",
            "let criticalBatteryPowerSaverRefreshInterval: TimeInterval = 60 * 60",
            "private func powerSaverActive() -> Bool",
            "batteryStatus?.powerSaverActive == true",
            "private func batteryPowerSaverRefreshInterval() -> TimeInterval?",
            "batteryStatus?.percent",
            "return criticalBatteryPowerSaverRefreshInterval",
            "return lowBatteryPowerSaverRefreshInterval",
            "private func powerSaverRefreshInterval(for status: ServiceStatus?) -> TimeInterval",
            "if let batteryInterval = batteryPowerSaverRefreshInterval(percent: batteryPercent)",
            "return batteryInterval",
            "return powerSaverCriticalRefreshInterval",
            "return powerSaverLowRefreshInterval",
            "return powerSaverHealthyRefreshInterval",
            "if powerSaverActive() {",
            "return powerSaverRefreshInterval(for: status)",
            "fixedRefreshInterval: fixedRefreshInterval()",
            "scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))",
            "private func rescheduleNextRefreshIfEarlier(after interval: TimeInterval)",
            "let desiredFireDate = Date().addingTimeInterval(interval)",
            "guard desiredFireDate < nextRefreshAt else",
        ]:
            self.assertIn(token, source)

        notification_handler = app_source.split("private func handlePowerSourceChanged()", 1)[1].split(
            "private func sampleBattery()", 1
        )[0]
        self.assertIn(
            "rescheduleNextRefreshIfEarlier(after: nextRefreshInterval(for: snapshot?.codex))",
            notification_handler,
        )
        self.assertNotIn("scheduleNextRefresh(after:", notification_handler)

        power_saver_body = app_source.split("private func powerSaverRefreshInterval(for status: ServiceStatus?)", 1)[1].split(
            "private func nextRefreshInterval", 1
        )[0]
        for token in [
            "powerPolicy.powerSaverRefreshInterval(",
            "statusOK: status?.ok == true",
            "fiveHourLeft: status?.fiveHourLeft",
            "sevenDayLeft: status?.sevenDayLeft",
            "batteryPercent: batteryStatus?.percent",
        ]:
            self.assertIn(token, power_saver_body)

        next_refresh_body = app_source.split("private func nextRefreshInterval(for status: ServiceStatus?)", 1)[1].split("private func nextRefreshCountdownText", 1)[0]
        self.assertLess(
            next_refresh_body.index("if powerSaverActive() {"),
            next_refresh_body.index("powerPolicy.nextRefreshInterval("),
        )

        policy_power_saver_body = source.split("func powerSaverRefreshInterval(statusOK: Bool, fiveHourLeft: Int?, sevenDayLeft: Int?, batteryPercent: Int?) -> TimeInterval", 1)[1].split(
            "func nextRefreshInterval(", 1
        )[0]
        self.assertLess(
            policy_power_saver_body.index("if let batteryInterval = batteryPowerSaverRefreshInterval(percent: batteryPercent)"),
            policy_power_saver_body.index("guard statusOK else"),
        )

    def test_privacy_docs_describe_battery_as_local_hardware_telemetry(self):
        privacy = pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8")

        for phrase in [
            "battery percentage and power-source state",
            "Power Saver",
            "stops SSD temperature and CPU/RAM sampling while on battery",
            "does not store battery history",
        ]:
            self.assertIn(phrase, privacy)

        self.assertNotIn("Battery-history", privacy)

    def test_build_script_stamps_public_version_metadata(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_VERSION="0.9.0"', script)
        self.assertIn('APP_BUILD="1"', script)
        self.assertIn('CFBundleShortVersionString</key>', script)
        self.assertIn('CFBundleVersion</key>', script)
        self.assertIn('CodexGaugeReleaseURL</key>', script)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases", script)
        self.assertIn("-framework UserNotifications", script)

    def test_native_app_resolves_helper_from_bundle_resources(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("Bundle.main.resourcePath", source)
        self.assertIn("resolveUsagePath", source)
        self.assertIn('"codex_status.py"', source)
        self.assertIn('"CodexGaugePythonPath"', source)
        self.assertIn('"CodexGaugeUsagePath"', source)
        self.assertNotIn("AILimitPythonPath", source)
        self.assertNotIn("AILimitUsagePath", source)
        self.assertNotIn('fallback: "\\(rootDir)/usage.py"', source)

    def test_native_app_logs_to_application_support(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("applicationSupportDirectory", source)
        self.assertIn('"CodexGauge"', source)
        self.assertIn('"CodexGauge-runtime.log"', source)
        self.assertIn("maxRuntimeLogBytes", source)
        self.assertIn("rotateLogIfNeeded", source)
        self.assertIn('appendingPathExtension("1")', source)
        self.assertNotIn('native/build/AiLimitStatus-runtime.log', source)
        self.assertIn('"Open Support Folder"', source)
        self.assertIn("disableAutomaticTermination", source)
        self.assertIn("disableSuddenTermination", source)
        self.assertIn("beginActivity", source)
        self.assertIn("automaticTerminationDisabled", source)
        self.assertIn("suddenTerminationDisabled", source)
        self.assertIn("applicationShouldTerminate", source)
        self.assertIn("allowTermination", source)
        self.assertIn(".terminateCancel", source)
        self.assertIn("launchAgentLabel", source)
        self.assertIn("unloadLaunchAgent", source)
        self.assertIn("launchctl", source)
        self.assertIn("bootout", source)
        self.assertIn("getuid()", source)
        self.assertNotIn("watchdogPidPath", source)
        self.assertNotIn("stopWatchdog", source)

    def test_native_app_shows_reset_timing_and_adaptive_refresh(self):
        source = native_swift_sources()

        self.assertIn("fiveHourReset", source)
        self.assertIn("sevenDayReset", source)
        self.assertIn('"5h resets"', source)
        self.assertIn('"7d resets"', source)
        self.assertIn("resetCountdown", source)
        self.assertIn("normalRefreshInterval", source)
        self.assertIn("watchRefreshInterval", source)
        self.assertIn("watchRefreshInterval: TimeInterval = 3 * 60", source)
        self.assertIn("criticalRefreshInterval", source)
        self.assertIn("failureRefreshInterval", source)
        self.assertIn("nextRefreshInterval", source)
        self.assertIn("scheduleNextRefresh", source)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", source)

    def test_native_app_uses_low_quota_warning_colors(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("normalQuotaColor", source)
        self.assertIn("warningQuotaColor", source)
        self.assertIn("criticalQuotaColor", source)
        self.assertIn("quotaColor", source)
        self.assertIn("bucketedGaugeColor", source)

    def test_native_app_has_light_dark_aware_menu_bar_colors(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("isDarkMenuBar", source)
        self.assertIn("NSApp.effectiveAppearance", source)
        self.assertIn("bestMatch(from:", source)
        self.assertIn("gaugePalette", source)


if __name__ == "__main__":
    unittest.main()
