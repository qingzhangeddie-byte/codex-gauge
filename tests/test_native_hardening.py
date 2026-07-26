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
    def test_storage_pipeline_is_removed_instead_of_runtime_disabled(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        helper = pathlib.Path("native/codex_status.py").read_text()

        for token in [
            "HistorySample",
            "persistentStorageEnabled",
            "historyFileName",
            "lastLiveCacheFileName",
            "removePersistentAppStorage",
            "localDataPathsForClearing",
            "clearLocalData",
            "generateUsageReport",
            '"Clear legacy"',
        ]:
            self.assertNotIn(token, source)

        for token in [
            "LOCAL_SNAPSHOT_MAX_FILES",
            "LAST_LIVE_CACHE_FILE",
            "CODEX_GAUGE_NO_STORAGE",
            "CODEX_GAUGE_READ_LOCAL_SNAPSHOT",
            "latest_local_codex_rate_limits_snapshot",
            "latest_last_live_rate_limits_cache",
            '.rglob("*.jsonl")',
        ]:
            self.assertNotIn(token, helper)

    def test_compact_signal_console_updates_in_place(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        refresh_body = source.split("private func refreshSignalPopoverIfNeeded", 1)[1].split(
            "private func applyTimerTolerance", 1
        )[0]

        self.assertIn("signalConsoleSize(quotaWindowCount:", source)
        self.assertIn("NSSize(width: 390, height: 210 + CGFloat(visibleCount - 1) * 68)", source)
        self.assertIn("private weak var signalConsolePanelView: SignalConsolePanelView?", source)
        self.assertIn("signalConsolePanelView?.update(model: model)", refresh_body)
        self.assertIn("signalPopover.contentSize != size", refresh_body)
        self.assertIn("makeSignalConsoleViewController(model: model, size: size)", refresh_body)

    def test_build_script_bundles_codex_helper_as_direct_single_binary(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_BINARY_NAME="$APP_NAME"', script)
        self.assertIn('LEGACY_APP_BINARY_NAME="${APP_NAME}-bin"', script)
        self.assertIn('APP_BINARY="$APP_MACOS/$APP_BINARY_NAME"', script)
        self.assertIn('stage_binary="$stage_macos/$APP_BINARY_NAME"', script)
        self.assertIn('BUILD_TARGET="$(uname -m)-apple-macosx${MIN_SYSTEM_VERSION}"', script)
        self.assertIn('swiftc -target "$BUILD_TARGET" "$BUILD_MAIN" -o "$stage_binary" -framework Cocoa -framework UserNotifications', script)
        self.assertIn('cp "$ROOT_DIR/native/codex_status.py" "$stage_resources/codex_status.py"', script)
        self.assertIn('cp "$ROOT_DIR/native/assets/CodexGauge.icns" "$stage_resources/CodexGauge.icns"', script)
        self.assertIn("CFBundleIconFile", script)
        self.assertIn("<string>CodexGauge</string>", script)
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

    def test_live_only_app_has_no_usage_storage_pipeline(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        build_script = pathlib.Path("script/build_and_run.sh").read_text()
        replace_script = pathlib.Path("script/replace_installed_app.sh").read_text()

        self.assertIn("Live only · no usage history", source)
        self.assertIn("Usage storage: none; launch at login uses a LaunchAgent", source)
        self.assertNotIn("persistentStorageEnabled", source)
        self.assertNotIn("CODEX_GAUGE_NO_STORAGE", source)
        self.assertNotIn("removePersistentAppStorage", source)
        self.assertNotIn("removeLegacySupportDirectory", source)
        self.assertNotIn("UserDefaults.standard", source)
        self.assertNotIn("try data.write", source)
        self.assertIn('LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"', build_script)
        self.assertIn('rm -rf "$LEGACY_SUPPORT_DIR"', build_script)
        self.assertIn('LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/CodexGauge"', replace_script)
        self.assertIn('rm -rf "$LEGACY_SUPPORT_DIR"', replace_script)

        append_log_body = source.split("private func appendLog", 1)[1].split("private func addDisabled", 1)[0]
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
            "quotaResetCountdown",
            "nextRefreshCountdownText",
            "drawMenuBarQuotaWindows",
            "drawMenuBarCountdownText",
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
            "Run Full Diagnostics",
            "Copy Diagnostics",
            "Check Now",
            "Done",
            "Live only · no usage history",
            "Usage storage: none; launch at login uses a LaunchAgent",
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
            "live-only",
            "does not read Codex session files",
            "Codex app-server",
            "startup login",
        ]:
            self.assertIn(phrase, privacy)
        for token in ["SSD", "CPU/RAM", "battery", "Battery", "Power Saver", "hardware"]:
            self.assertNotIn(token, privacy)


if __name__ == "__main__":
    unittest.main()
