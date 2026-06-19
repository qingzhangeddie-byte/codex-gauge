import pathlib
import unittest


class NativeCodexOnlyTests(unittest.TestCase):
    def test_native_app_uses_codex_only_status_command(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("--status-json", source)
        self.assertIn('"codex_status.py"', source)
        self.assertNotIn('"--codex-status-json"', source)
        self.assertNotIn('"usage.py"', source)

    def test_native_app_uses_bundled_live_codex_app_server_helper(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("Bundle.main.resourcePath", source)
        self.assertNotIn('"--allow-codex-auth"', source)
        self.assertNotIn('"--allow-browser-cookies"', source)
        self.assertIn("var helperEnv: [String: String] = [", source)
        self.assertIn("helperEnvironment", source)
        self.assertIn('"HOME": NSHomeDirectory()', source)
        self.assertIn('"CODEX_CI": "1"', source)
        self.assertIn('"CODEX_SHELL": "1"', source)
        self.assertIn('"CODEX_HOME":', source)
        self.assertNotIn('"CODEX_THREAD_ID"', source)
        self.assertIn("process.executableURL = URL(fileURLWithPath: pythonPath)", source)
        self.assertIn('process.arguments = [usagePath, "--status-json"]', source)
        self.assertIn("process.environment = helperEnvironment()", source)
        self.assertNotIn('process.arguments = ["asuser", "\\(getuid())", "/usr/bin/env"]', source)
        self.assertNotIn("helperEnvironmentAssignments", source)
        self.assertIn("readabilityHandler", source)
        self.assertIn("stdoutBuffer", source)
        self.assertIn("stderrBuffer", source)
        refresh_section = source[source.index("private func refresh()"):source.index("private func finishRefresh")]
        self.assertNotIn('"asuser"', refresh_section)
        self.assertIn("URL(fileURLWithPath: pythonPath)", refresh_section)
        self.assertNotIn('"/usr/bin/env"', refresh_section)
        self.assertIn("CODEX_GAUGE_STATUS_HELPER", source)
        self.assertNotIn("ProcessInfo.processInfo.environment", source)
        self.assertNotIn("AI_LIMIT_ALLOW_CODEX_AUTH", source)
        self.assertNotIn("AI_LIMIT_ALLOW_BROWSER_COOKIES", source)
        self.assertNotIn('AI_LIMIT_ALLOW_CODEX_APP_SERVER', source)
        self.assertNotIn('AI_LIMIT_CODEX_APP_SERVER_ONLY', source)
        self.assertIn("codexCliBundlePath", source)
        self.assertIn("isExecutableFile(atPath: codexCliBundlePath)", source)
        self.assertIn("/Applications/Codex.app/Contents/Resources", source)

    def test_native_app_auto_refreshes_adaptively(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("normalRefreshInterval: TimeInterval = 5 * 60", source)
        self.assertIn("watchRefreshInterval: TimeInterval = 3 * 60", source)
        self.assertIn("5 * 60", source)
        self.assertIn("3 * 60", source)
        self.assertIn("2 * 60", source)
        self.assertNotIn("15 * 60", source)
        self.assertIn("nextRefreshInterval", source)
        self.assertIn("Timer(timeInterval: interval", source)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", source)

    def test_native_app_writes_runtime_status_log(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("CodexGauge-runtime.log", source)
        self.assertIn("appendLog", source)
        self.assertIn("title=\\(decoded.title)", source)

    def test_native_app_clears_stale_snapshot_on_refresh_failure(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        finish_refresh = source[source.index("private func finishRefresh"):source.index("private func rebuildMenu")]

        self.assertIn("snapshot = nil", finish_refresh)
        self.assertLess(
            finish_refresh.index("snapshot = nil"),
            finish_refresh.index('lastError = "Could not parse status JSON'),
        )
        self.assertIn("scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))", finish_refresh)

    def test_native_app_draws_plan_b_four_bar_status_image(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("statusItemWidth: CGFloat = 306", source)
        self.assertIn("statusImageSize = NSSize(width: 300, height: 22)", source)
        self.assertIn("menuBarCodexContentX: CGFloat = 30", source)
        self.assertIn("resetRailWidth: CGFloat = 18", source)
        self.assertIn("makeStatusImage", source)
        self.assertIn("fiveHourReset: status.fiveHourReset", source)
        self.assertIn("sevenDayReset: status.sevenDayReset", source)
        self.assertIn("drawPlanBGauge", source)
        self.assertIn('drawPlanBRow(window: "5h"', source)
        self.assertIn('drawPlanBRow(window: "7d"', source)
        self.assertIn("drawQuotaRail", source)
        self.assertIn("drawResetMoodLane", source)
        self.assertIn("drawResetMoodFace", source)
        self.assertIn("NSBezierPath(ovalIn: faceRect)", source)
        self.assertIn("mouth.curve(", source)
        self.assertIn("NSRect(x: x + 98, y: y, width: resetRailWidth, height: 3)", source)
        self.assertIn("NSPoint(x: x + 122, y: y - 2.9)", source)
        self.assertNotIn("private func resetMoodFace", source)
        for emoji in ["😡", "😟", "🙁", "😐", "🙂", "😊", "😄"]:
            self.assertNotIn(emoji, source)
        self.assertIn("fiveHourResetCountdown", source)
        self.assertIn("sevenDayResetCountdown", source)
        self.assertIn("resetProgressPercent", source)
        self.assertIn("bucketedGaugeColor", source)
        self.assertIn("resetLaneColor", source)
        self.assertIn("fillColor: quotaColor(value)", source)
        self.assertIn("markerX = rect.minX + (rect.width - markerWidth) * fraction", source)
        self.assertIn("laneColor.withAlphaComponent(0.68)", source)
        self.assertIn("moodPulseStep", source)
        self.assertIn("animationTimer", source)
        self.assertIn("startMoodAnimation", source)
        self.assertIn("moodAnimationFrameLimit", source)
        self.assertIn("Timer(timeInterval: 0.18, repeats: true)", source)
        self.assertIn("stopMoodAnimation()", source)
        self.assertNotIn("Timer(timeInterval: 2.4, repeats: true)", source)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", source)
        self.assertIn('statusItem.autosaveName = "CodexGaugeStatusItem"', source)
        self.assertIn("statusItem.length = statusItemWidth", source)
        self.assertIn("button.imagePosition = .imageOnly", source)
        self.assertIn('button.title = ""', source)
        self.assertIn("button.image = makeStatusImage(", source)
        self.assertIn("drawMenuBarSystemPod", source)
        self.assertIn("systemMetricMenuBarText", source)
        self.assertIn("menuBarTooltipTitle(title: title, status: status)", source)
        self.assertNotIn("drawSevenDayResetCountdown", source)
        self.assertNotIn("drawWordmark", source)
        self.assertNotIn('("Codex" as NSString).draw', source)
        self.assertNotIn("drawStatusLetters", source)

    def test_native_app_dropdown_keeps_detailed_codex_pro_meter_rows(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Codex Pro"', source)
        self.assertIn('"5-hour left"', source)
        self.assertIn('"7-day left"', source)
        self.assertIn("barString", source)
        self.assertIn('"Live · refreshed"', source)
        self.assertIn('"Snapshot · refreshed"', source)
        self.assertIn("refreshLabel", source)
        self.assertIn("statusTooltipTitle", source)

    def test_native_app_marks_non_live_data_sources_in_menu_bar(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Last live ·"', source)
        self.assertIn('case "last_live"', source)
        self.assertIn("drawSourceIndicator(source: source", source)
        self.assertNotIn("drawStatusStateBadge(source: source, palette: palette)", source)
        self.assertIn("statusImageStateLabel(source: source", source)
        self.assertIn('return "Cache"', source)
        self.assertIn('return "Snapshot"', source)
        self.assertIn('return "Open"', source)
        self.assertIn("sourceIndicatorColor", source)
        self.assertIn("Last live", source)

    def test_native_app_surfaces_version_and_release_link(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Codex Gauge v"', source)
        self.assertIn("appVersion", source)
        self.assertIn("openReleases", source)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases", source)
        self.assertIn('"Check for Updates..."', source)

    def test_native_app_has_preferences_for_refresh_notifications_and_login(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Preferences..."', source)
        self.assertIn("openPreferences", source)
        self.assertIn("NSWindow", source)
        self.assertIn("NSPopUpButton", source)
        self.assertIn("refreshModeKey", source)
        self.assertIn("notificationsEnabledKey", source)
        self.assertIn("launchAtLoginKey", source)
        self.assertIn('"Adaptive"', source)
        self.assertIn('"5 minutes"', source)
        self.assertIn('"10 minutes"', source)
        self.assertIn('"Launch at login"', source)
        self.assertIn('"Quota notifications"', source)
        self.assertIn("refreshPreferenceChanged", source)
        self.assertIn("notificationsPreferenceChanged", source)
        self.assertIn("launchAtLoginPreferenceChanged", source)
        self.assertIn("installLaunchAgentForCurrentApp", source)
        self.assertIn("removeLaunchAgentPlist", source)
        self.assertIn("makeThemedUtilityContentView", source)
        self.assertIn("ThemedUtilityPanelView", source)
        self.assertIn("styleUtilityButton", source)

    def test_native_app_has_first_run_setup_window(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('firstRunSetupSeenKey = "firstRunSetupSeen"', source)
        self.assertIn("firstRunSetupWindow", source)
        self.assertIn("firstRunSetupPopover", source)
        self.assertIn("showFirstRunSetupIfNeeded", source)
        self.assertIn("showFirstRunSetupPopover", source)
        self.assertIn("makeFirstRunSetupWindow", source)
        self.assertIn("completeFirstRunSetup", source)
        self.assertIn('"Start in menu bar"', source)
        self.assertIn('"Local first. No cookies."', source)
        self.assertIn('"Open Codex"', source)
        self.assertIn('"Run Check"', source)
        self.assertIn("orderFrontRegardless", source)
        self.assertIn(".canJoinAllSpaces", source)
        self.assertIn("show(relativeTo: button.bounds", source)
        self.assertIn("firstRunSetupPopover?.performClose", source)
        self.assertIn("UserDefaults.standard.set(true, forKey: firstRunSetupSeenKey)", source)

    def test_native_app_sends_opt_in_quota_notifications(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("import UserNotifications", source)
        self.assertIn("UNUserNotificationCenter.current()", source)
        self.assertIn("requestAuthorization", source)
        self.assertIn("postNotification", source)
        self.assertIn("handleNotificationTransitions", source)
        self.assertIn("fiveHourLowNotification", source)
        self.assertIn("fiveHourRestoredNotification", source)
        self.assertIn("liveUnavailableNotification", source)
        self.assertIn("previousFiveHourLeft", source)
        self.assertIn("liveUnavailableSince", source)
        self.assertIn("notificationsEnabled()", source)
        self.assertIn("decoded.codex", source)

    def test_native_app_does_not_expose_claude_menu_items(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertNotIn("openClaudeUsage", source)
        self.assertNotIn("Open Claude", source)
        self.assertNotIn("claude", source.lower())

    def test_docs_describe_live_app_server_for_native_app(self):
        readme = pathlib.Path("README.md").read_text()
        zh_readme = pathlib.Path("README.zh-CN.md").read_text()

        self.assertIn("local Codex app-server", readme)
        self.assertIn("本地 Codex app-server", zh_readme)
        self.assertNotIn("explicitly disables the Codex `app-server`", readme)
        self.assertNotIn("明确关闭 Codex `app-server`", zh_readme)


if __name__ == "__main__":
    unittest.main()
