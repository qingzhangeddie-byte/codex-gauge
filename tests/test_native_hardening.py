import pathlib
import unittest


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
        self.assertIn("maxSystemMetricSamples = 24 * 60 * 60 / 5", source)
        self.assertIn("systemMetricsHistoryPath,", source)
        self.assertIn("Clear local data", source)
        self.assertIn("CPU/RAM", pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8"))
        self.assertIn("aggregated local CPU and RAM percentages", pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8"))

        metric_storage = source.split("private func appendSystemMetricSample", 1)[1].split("private func readSystemMetricSamples", 1)[0]
        self.assertNotIn("Keychain", metric_storage)
        self.assertNotIn("browser", metric_storage.lower())
        self.assertNotIn("auth.json", metric_storage)

    def test_build_script_stamps_public_version_metadata(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_VERSION="0.8.0"', script)
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
        source = pathlib.Path("native/CodexGauge.swift").read_text()

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
