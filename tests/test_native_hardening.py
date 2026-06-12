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

    def test_build_script_stamps_public_version_metadata(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()

        self.assertIn('APP_VERSION="0.4.0"', script)
        self.assertIn('APP_BUILD="1"', script)
        self.assertIn('CFBundleShortVersionString</key>', script)
        self.assertIn('CFBundleVersion</key>', script)
        self.assertIn('CodexGaugeReleaseURL</key>', script)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases", script)

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
