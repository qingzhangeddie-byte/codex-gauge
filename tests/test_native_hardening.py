import pathlib
import unittest


HARDWARE_TOKENS = [
    "SSDTemperatureStatus",
    "TemperatureSample",
    "SystemMetricSample",
    "BatteryStatus",
    "showSSDTemperature",
    "ssdTemperature",
    "systemMetric",
    "batteryStatus",
    "Power Saver",
    "IOPS",
    "IOReport",
    "CodexGaugePowerPolicy",
]


class NativeHardeningTests(unittest.TestCase):
    def test_build_script_bundles_codex_helper_as_direct_single_binary(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_BINARY_NAME="$APP_NAME"', script)
        self.assertIn('LEGACY_APP_BINARY_NAME="${APP_NAME}-bin"', script)
        self.assertIn('APP_BINARY="$APP_MACOS/$APP_BINARY_NAME"', script)
        self.assertIn('stage_binary="$stage_macos/$APP_BINARY_NAME"', script)
        self.assertIn('swiftc "$BUILD_MAIN" -o "$stage_binary" -framework Cocoa -framework UserNotifications', script)
        self.assertIn('cp "$ROOT_DIR/native/codex_status.py" "$stage_resources/codex_status.py"', script)
        self.assertIn('<string>$APP_NAME</string>', script)
        self.assertIn('ditto --norsrc --noextattr "$stage_bundle" "$APP_BUNDLE"', script)
        self.assertIn('pkill -x "$LEGACY_APP_BINARY_NAME"', script)
        self.assertNotIn("APP_LAUNCHER", script)
        self.assertNotIn("stage_launcher", script)
        self.assertNotIn("SUPPORT_SWIFT_SOURCES", script)
        self.assertNotIn("-framework IOKit", script)
        self.assertNotIn("SSD_TEMPERATURE", script)
        self.assertNotIn("launchctl bootstrap", script)
        self.assertNotIn("<key>KeepAlive</key>", script)

    def test_native_app_and_scripts_do_not_ship_hardware_helpers(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        combined_scripts = "\n".join(path.read_text() for path in pathlib.Path("script").glob("*.sh"))

        self.assertFalse(pathlib.Path("native/ssd_temperature.m").exists())
        self.assertFalse(pathlib.Path("native/CodexGaugePowerPolicy.swift").exists())
        for token in HARDWARE_TOKENS:
            self.assertNotIn(token, source)
            self.assertNotIn(token, combined_scripts)
        self.assertNotIn("readCPUUsagePercent", source)
        self.assertNotIn("readRAMUsagePercent", source)

    def test_zero_persistence_disables_app_storage_and_preferences(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        build_script = pathlib.Path("script/build_and_run.sh").read_text()
        replace_script = pathlib.Path("script/replace_installed_app.sh").read_text()

        self.assertIn("private let persistentStorageEnabled = false", source)
        self.assertIn('"CODEX_GAUGE_NO_STORAGE": "1"', source)
        self.assertIn("removePersistentAppStorage()", source)
        self.assertIn("removeLegacySupportDirectory()", source)
        self.assertIn("Zero persistence", source)
        self.assertNotIn("UserDefaults.standard", source)
        self.assertNotIn("try data.write", source)
        self.assertIn('LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"', build_script)
        self.assertIn('rm -rf "$LEGACY_SUPPORT_DIR"', build_script)
        self.assertIn('LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"', replace_script)
        self.assertIn('rm -rf "$LEGACY_SUPPORT_DIR"', replace_script)

        append_log_body = source.split("private func appendLog", 1)[1].split("private func rotateLogIfNeeded", 1)[0]
        self.assertNotIn("FileHandle", append_log_body)
        self.assertNotIn("write(to:", append_log_body)
        self.assertNotIn("createDirectory", append_log_body)

    def test_native_app_shows_reset_timing_and_adaptive_refresh_without_power_policy(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "normalRefreshInterval: TimeInterval = 5 * 60",
            "watchRefreshInterval: TimeInterval = 3 * 60",
            "criticalRefreshInterval: TimeInterval = 2 * 60",
            "tenMinuteRefreshInterval: TimeInterval = 10 * 60",
            "nextRefreshInterval(for status: ServiceStatus?)",
            "fiveHourResetCountdown",
            "sevenDayResetCountdown",
            "nextRefreshCountdownText",
            "drawMenuBarRefreshCountdown",
            "drawMenuBarCountdownPill",
        ]:
            self.assertIn(token, source)
        self.assertNotIn("batteryPowerSaverRefreshInterval", source)
        self.assertNotIn("powerSaverRefreshInterval", source)

    def test_updater_verifies_public_bundle_identity_and_direct_executable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        body = source.split("private func verifyDownloadedUpdateApp", 1)[1].split(
            "private func verifyDownloadedUpdateSignature", 1
        )[0]

        self.assertIn('bundleIdentifier == "app.codexgauge.menubar"', body)
        self.assertIn('appURL.appendingPathComponent("Contents/MacOS/CodexGauge")', body)
        self.assertIn('appURL.appendingPathComponent("Contents/Resources/codex_status.py")', body)
        self.assertIn("isExecutableFile", body)
        self.assertIn("isReadableFile", body)
        self.assertNotIn("CodexGauge-bin", body)
        self.assertNotIn("ssd_temperature", body)

    def test_utility_windows_use_codex_only_privacy_safe_copy(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for label in [
            "Blue Ceramic",
            "Zero persistence",
            "No stored cache or snapshot",
            "Run Full Diagnostics",
            "Copy Diagnostics",
            "Check Now",
            "Done",
            "Codex-only signal",
            "No device telemetry sampled",
        ]:
            self.assertIn(f'"{label}"', source)

        for blocked in [
            '"/Users/',
            '"Share Report"',
            '"Open Support Folder"',
            '"Battery mode"',
        ]:
            self.assertNotIn(blocked, source)

    def test_privacy_docs_describe_codex_only_local_behavior(self):
        privacy = pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8")

        for phrase in [
            "does not read browser cookies",
            "does not read `~/.codex/auth.json`",
            "zero persistence",
            "Codex app-server",
            "does not install a LaunchAgent",
        ]:
            self.assertIn(phrase, privacy)
        for token in ["SSD", "CPU/RAM", "battery", "Battery", "Power Saver", "hardware"]:
            self.assertNotIn(token, privacy)


if __name__ == "__main__":
    unittest.main()
