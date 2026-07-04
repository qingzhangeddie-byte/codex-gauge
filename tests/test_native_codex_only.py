import pathlib
import unittest


def native_swift_sources() -> str:
    return "\n".join(
        path.read_text()
        for path in sorted(pathlib.Path("native").glob("CodexGauge*.swift"))
    )


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
        source = native_swift_sources()

        self.assertIn("normalRefreshInterval: TimeInterval = 5 * 60", source)
        self.assertIn("watchRefreshInterval: TimeInterval = 3 * 60", source)
        self.assertIn("5 * 60", source)
        self.assertIn("3 * 60", source)
        self.assertIn("2 * 60", source)
        self.assertIn("recoveryRefreshInterval: TimeInterval = 60", source)
        self.assertNotIn("15 * 60", source)
        self.assertIn("nextRefreshInterval", source)
        self.assertIn("Timer(timeInterval: interval", source)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", source)
        refresh_body = source.split("private func nextRefreshInterval", 1)[1].split(
            "private func nextRefreshCountdownText", 1
        )[0]
        self.assertIn("guard let status else", refresh_body)
        self.assertIn("guard status.ok && !isNonLiveSource(status.source) else", refresh_body)
        self.assertIn("return recoveryRefreshInterval", refresh_body)

    def test_native_app_does_not_write_runtime_status_log(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("CodexGauge-runtime.log", source)
        self.assertIn("appendLog", source)
        self.assertIn("title=\\(decoded.title)", source)
        append_log_body = source.split("private func appendLog", 1)[1].split("private func rotateLogIfNeeded", 1)[0]
        self.assertNotIn("FileHandle", append_log_body)
        self.assertNotIn("write(to:", append_log_body)
        self.assertNotIn("createDirectory", append_log_body)

    def test_native_app_preserves_last_visible_quota_on_refresh_failure(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        finish_refresh = source[source.index("private func finishRefresh"):source.index("private func rebuildMenu")]

        self.assertIn("let previousSnapshot = snapshot", finish_refresh)
        self.assertIn("if isLiveRefreshFailure(decoded.codex), let previousSnapshot", finish_refresh)
        self.assertIn("snapshot = previousSnapshot", finish_refresh)
        self.assertIn("lastError = decoded.codex.error ??", finish_refresh)
        self.assertIn("setStatusImage(title: statusTooltipTitle(previousSnapshot), status: previousSnapshot.codex)", finish_refresh)
        self.assertIn("scheduleNextRefresh(after: lastError == nil ? nextRefreshInterval(for: snapshot?.codex) : recoveryRefreshInterval)", finish_refresh)

    def test_native_app_draws_codex_usage_in_native_status_view(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("statusItemWidth: CGFloat = 94", source)
        self.assertIn("private final class CodexGaugeStatusItemView", source)
        self.assertIn("private lazy var statusItemView", source)
        self.assertIn("button.addSubview(statusItemView)", source)
        self.assertIn("statusItemView.autoresizingMask = [.width, .height]", source)
        self.assertIn("statusItemView.onDraw", source)
        self.assertIn("statusItemView.onClick", source)
        self.assertIn("override func viewDidChangeEffectiveAppearance()", source)
        self.assertIn("needsDisplay = true", source.split("override func viewDidChangeEffectiveAppearance()", 1)[1])
        self.assertIn("drawStatusItemView(in:", source)
        self.assertIn("menuBarUsagePercentRect", source)
        self.assertIn("menuBarHorizontalRailRect", source)
        self.assertIn("menuBarRefreshCountdownRect", source)
        self.assertIn("quotaRailSize = NSSize(width: 22, height: 5)", source)
        self.assertIn("fiveHourReset: status.fiveHourReset", source)
        self.assertIn("sevenDayReset: status.sevenDayReset", source)
        self.assertIn("drawPlanBGauge", source)
        self.assertIn("drawMenuBarUsagePercentBars(", source)
        self.assertIn('drawMenuBarUsagePercentRow(window: "5h"', source)
        self.assertIn('drawMenuBarUsagePercentRow(window: "7d"', source)
        self.assertIn("drawMenuBarHorizontalQuotaBar(value:", source)
        self.assertIn("systemMonitorMenuBarTextColor", source)
        self.assertIn("systemMonitorMenuBarBlue", source)
        self.assertIn("drawMenuBarRefreshCountdown(", source)
        self.assertIn("drawMenuBarCountdownText(text: fiveHourText", source)
        self.assertIn("drawMenuBarCountdownText(text: sevenDayText", source)
        self.assertIn("(resetText as NSString).draw", source)
        self.assertNotIn("private func resetMoodFace", source)
        self.assertNotIn("private func drawResetMoodFace", source)
        self.assertNotIn("private func drawResetMoodLane", source)
        for emoji in ["😡", "😟", "🙁", "😐", "🙂", "😊", "😄"]:
            self.assertNotIn(emoji, source)
        self.assertIn("fiveHourResetCountdown", source)
        self.assertIn("sevenDayResetCountdown", source)
        self.assertIn("resetProgressPercent", source)
        self.assertIn("bucketedGaugeColor", source)
        self.assertIn("resetLaneColor", source)
        self.assertIn("fillColor: systemMonitorMenuBarBlue()", source)
        self.assertIn("let cornerRadius = min(0.9, rect.height / 4.0)", source)
        self.assertIn("let minimumVisibleFillWidth: CGFloat = 2.4", source)
        self.assertIn("max(minimumVisibleFillWidth, trackRect.width * fraction)", source)
        self.assertIn("track.addClip()", source)
        self.assertIn("fillRect.fill()", source)
        self.assertIn("statusItemView.window?.effectiveAppearance ?? statusItemView.effectiveAppearance", source)
        self.assertIn("NSColor(calibratedWhite: 0.97, alpha: 0.96)", source)
        self.assertIn("Sampled from the adjacent iStat Menus CPU fill block (#8696B9).", source)
        self.assertIn("NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)", source)
        self.assertIn("Sampled from the adjacent iStat Menus CPU meter well around the blue fill.", source)
        self.assertIn("NSColor(deviceWhite: 0.08, alpha: 0.95)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.525, green: 0.588, blue: 0.725, alpha: 1.0)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.18, green: 0.56, blue: 0.96, alpha: 0.92)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.75, alpha: 0.98)", source)
        self.assertNotIn("NSColor(calibratedWhite: 1.0, alpha: 0.12)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.07)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.07, alpha: 0.96)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.16)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.12)", source)
        self.assertNotIn("let innerRect = rect.insetBy(dx: 1.0, dy: 1.0)", source)
        self.assertNotIn("systemMonitorMenuBarMeterOutlineColor().setStroke()", source)
        self.assertNotIn("let cornerRadius = rect.height / 2", source)
        self.assertIn("moodPulseStep", source)
        self.assertIn("animationTimer", source)
        self.assertIn("startMoodAnimation", source)
        self.assertIn("moodAnimationFrameLimit", source)
        self.assertIn("stopMoodAnimation()", source)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", source)
        self.assertNotIn('statusItem.autosaveName = "CodexGaugeStatusItem"', source)
        self.assertIn("statusItem.length = statusItemWidth", source)
        self.assertIn("statusItemView.needsDisplay = true", source)
        self.assertNotIn("button.image = makeStatusImage(", source)
        self.assertNotIn("button.imageScaling", source)
        self.assertNotIn("statusItem.view = statusItemView", source)
        self.assertIn("menuBarTooltipTitle(title: title, status: status)", source)

        draw_status_body = source.split("private func drawStatusItemView", 1)[1].split(
            "private func morandiMenuBarSage", 1
        )[0]
        self.assertIn("drawPlanBGauge(", draw_status_body)
        self.assertNotIn("drawMenuBarHardwareSignals(", draw_status_body)
        self.assertNotIn("ssdTemperature:", draw_status_body)
        self.assertNotIn("systemMetric:", draw_status_body)
        self.assertNotIn("batteryStatus:", draw_status_body)
        self.assertNotIn("drawMenuBarHardwareSignals", source)
        self.assertNotIn("drawMenuBarSystemMetricStrip", source)
        self.assertNotIn("drawMenuBarSSDTemperature", source)
        self.assertNotIn("drawMenuBarBatteryModeInfo", source)
        self.assertNotIn("drawMenuBarBattery(status:", draw_status_body)
        self.assertNotIn("drawSevenDayResetCountdown", source)
        self.assertNotIn("drawWordmark", source)
        self.assertNotIn('("Codex" as NSString).draw', source)
        self.assertNotIn("drawStatusLetters", source)

    def test_status_item_view_avoids_raster_image_scaling(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        draw_status_body = source.split("private func drawStatusItemView", 1)[1].split(
            "private func morandiMenuBarSage", 1
        )[0]
        animation_body = source.split("private func startMoodAnimation", 1)[1].split(
            "private func stopMoodAnimation", 1
        )[0]

        self.assertNotIn("private func makeStatusImage", source)
        self.assertNotIn("NSBitmapImageRep", draw_status_body)
        self.assertNotIn("NSGraphicsContext(bitmapImageRep:", draw_status_body)
        self.assertNotIn("context.cgContext.scaleBy", draw_status_body)
        self.assertNotIn("button.imageScaling", source)
        self.assertIn("private final class CodexGaugeStatusItemView", source)
        self.assertIn("override func draw(_ dirtyRect: NSRect)", source)
        self.assertIn("onDraw?(bounds)", source)
        self.assertIn("private func statusPixelAlignedPoint", source)
        self.assertIn("private func statusPixelAlignedRect", source)
        self.assertIn("statusPixelAlignedPoint", source.split("private func drawMenuBarUsagePercentRow", 1)[1])
        self.assertIn("statusPixelAlignedRect", source.split("private func drawMenuBarUsagePercentBars", 1)[1])
        self.assertNotIn("private func drawMenuBarVerticalQuotaMeter", source)
        self.assertIn("guard animationTimer == nil", animation_body)
        self.assertNotIn("Timer(timeInterval: 0.18, repeats: true)", animation_body)

    def test_native_app_watchdog_marks_live_failures_without_extra_badges(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()
        draw_status_body = source.split("private func drawStatusItemView", 1)[1].split(
            "private func morandiMenuBarSage", 1
        )[0]

        self.assertIn("isLiveWarningStatus", source)
        self.assertIn("private func isLiveRefreshFailure", source)
        self.assertIn("let liveWarning = isLiveWarningStatus(status)", draw_status_body)
        self.assertIn("if liveWarning", draw_status_body)
        self.assertIn("drawMenuBarLiveUnavailableHint", source)
        self.assertIn("drawLiveWarningGauge(fiveHourLeft:", source)
        self.assertIn("fiveHourReset: status?.fiveHourReset", draw_status_body)
        self.assertIn("sevenDayReset: status?.sevenDayReset", draw_status_body)
        live_hint_body = source.split("private func drawMenuBarLiveUnavailableHint", 1)[1].split(
            "private func drawPlanBGauge", 1
        )[0]
        self.assertIn('text: "--"', live_hint_body)
        self.assertNotIn('text: "open"', live_hint_body)
        self.assertNotIn('text: "Codex"', live_hint_body)
        self.assertNotIn("drawStatusStateBadge", source)
        self.assertNotIn("drawSourceIndicator", source)

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

    def test_native_app_keeps_non_live_state_detail_out_of_the_menu_bar_glyph(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Last live ·"', source)
        self.assertIn('case "last_live"', source)
        self.assertIn("Last live", source)
        self.assertIn("menuBarTooltipTitle(title: title, status: status)", source)
        self.assertNotIn("drawSourceIndicator", source)
        self.assertNotIn("drawStatusStateBadge", source)
        self.assertNotIn("statusImageStateLabel", source)
        self.assertNotIn("sourceIndicatorColor", source)

    def test_native_app_surfaces_version_and_release_link(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Codex Gauge v"', source)
        self.assertIn("appVersion", source)
        self.assertIn("openReleases", source)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases", source)
        self.assertIn('"Check for Updates..."', source)

    def test_native_app_can_download_and_install_confirmed_github_updates(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private struct GitHubRelease",
            "private struct GitHubReleaseAsset",
            "latestReleaseAPIURL",
            "https://api.github.com/repos/qingzhangeddie-byte/codex-gauge/releases/latest",
            "checkForUpdates",
            "fetchLatestRelease",
            "showUpdatePrompt",
            "Install Update",
            "downloadAndInstallUpdate",
            "prepareDownloadedUpdate",
            "findDownloadedCodexGaugeApp",
            "verifyDownloadedUpdateApp",
            "installPreparedUpdate",
            "CodexGauge-update-",
            "NSTemporaryDirectory()",
            "ditto",
            "codesign",
            "CFBundleShortVersionString",
            "CFBundleIdentifier",
            "app.codexgauge.menubar",
            "appVersionIsNewer",
            "compareVersionStrings",
            "lastUpdateSummary",
        ]:
            self.assertIn(token, source)

        self.assertIn('addAction("Check for Updates...", action: #selector(checkForUpdates))', source)
        self.assertIn("URLSession.shared.dataTask", source)
        self.assertIn("URLSession.shared.downloadTask", source)
        self.assertIn("release.body", source)
        self.assertIn("browser_download_url", source)
        self.assertIn(".zip", source)
        self.assertIn("runDetachedUpdateInstaller", source)
        self.assertIn("NSApp.terminate(nil)", source)
        self.assertNotIn("dismissedUpdate", source)

    def test_native_app_runs_session_only_automatic_update_check_once(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private enum UpdateCheckMode",
            "case manual",
            "case automatic",
            "private var automaticUpdateTimer: Timer?",
            "private var automaticUpdateCheckDidRun = false",
            "private var automaticUpdateSkippedTagName: String?",
            "private let automaticUpdateCheckDelay: TimeInterval = 2 * 60",
            "scheduleAutomaticUpdateCheck()",
            "performAutomaticUpdateCheckIfAllowed()",
            "performUpdateCheck(mode: .automatic)",
            "handleLatestRelease(release, mode: mode)",
            "handleUpdateCheckFailure(error, mode: mode)",
        ]:
            self.assertIn(token, source)

        launch_body = source.split("func applicationDidFinishLaunching", 1)[1].split(
            "func applicationWillTerminate", 1
        )[0]
        self.assertIn("scheduleAutomaticUpdateCheck()", launch_body)

        terminate_body = source.split("func applicationWillTerminate", 1)[1].split(
            "func applicationShouldTerminate", 1
        )[0]
        self.assertIn("automaticUpdateTimer?.invalidate()", terminate_body)

        schedule_body = source.split("private func scheduleAutomaticUpdateCheck()", 1)[1].split(
            "private func performAutomaticUpdateCheckIfAllowed()", 1
        )[0]
        self.assertIn("Timer(timeInterval: automaticUpdateCheckDelay, repeats: false)", schedule_body)
        self.assertIn("applyTimerTolerance(nextTimer, interval: automaticUpdateCheckDelay)", schedule_body)
        self.assertIn("RunLoop.main.add(nextTimer, forMode: .common)", schedule_body)

        automatic_body = source.split("private func performAutomaticUpdateCheckIfAllowed()", 1)[1].split(
            "@objc private func checkForUpdates()", 1
        )[0]
        self.assertIn("guard !automaticUpdateCheckDidRun else", automatic_body)
        self.assertIn("automaticUpdateCheckDidRun = true", automatic_body)
        self.assertIn("performUpdateCheck(mode: .automatic)", automatic_body)
        self.assertNotIn("automaticUpdateCheckPendingForPower", source)
        self.assertNotIn("resumeAutomaticUpdateCheckAfterPowerReturns", source)
        self.assertNotIn("powerSaverActive", source)

    def test_native_app_suppresses_skipped_automatic_update_prompts_without_blocking_manual_checks(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("@objc private func checkForUpdates()", source)
        manual_body = source.split("@objc private func checkForUpdates()", 1)[1].split(
            "private func performUpdateCheck", 1
        )[0]
        self.assertIn("automaticUpdateTimer?.invalidate()", manual_body)
        self.assertIn("automaticUpdateCheckDidRun = true", manual_body)
        self.assertNotIn("automaticUpdateCheckPendingForPower", manual_body)
        self.assertIn("performUpdateCheck(mode: .manual)", manual_body)

        latest_body = source.split("private func handleLatestRelease(_ release: GitHubRelease, mode: UpdateCheckMode)", 1)[1].split(
            "private func showUpdateInfo", 1
        )[0]
        self.assertIn("mode == .manual", latest_body)
        self.assertIn("mode == .automatic", latest_body)
        self.assertIn("automaticUpdateSkippedTagName == release.tagName", latest_body)
        self.assertIn("showUpdatePrompt(release: release, asset: asset, latestVersion: latestVersion, mode: mode)", latest_body)
        self.assertNotIn("openURL(release.htmlURL)", latest_body.split("mode == .automatic", 1)[-1])

        prompt_body = source.split("private func showUpdatePrompt", 1)[1].split(
            "private func downloadAndInstallUpdate", 1
        )[0]
        self.assertIn('alert.addButton(withTitle: "Install Update")', prompt_body)
        self.assertIn('alert.addButton(withTitle: "Skip this version")', prompt_body)
        self.assertIn('alert.addButton(withTitle: "Remind me later")', prompt_body)
        self.assertIn("case .alertSecondButtonReturn:", prompt_body)
        self.assertIn("automaticUpdateSkippedTagName = release.tagName", prompt_body)
        self.assertNotIn("openURL(release.htmlURL)", prompt_body)

    def test_automatic_update_failures_are_quiet_and_non_persistent(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func handleUpdateCheckFailure", source)
        failure_body = source.split("private func handleUpdateCheckFailure", 1)[1].split(
            "private func fetchLatestRelease", 1
        )[0]
        self.assertIn('lastUpdateSummary = "Update check unavailable"', failure_body)
        self.assertIn("guard mode == .manual else", failure_body)
        self.assertIn('appendLog("automatic update check failed=', failure_body)
        self.assertIn('showReportAlert(title: "Could not check for updates"', failure_body)

        self.assertNotIn("UserDefaults.standard", failure_body)
        self.assertNotIn("automaticUpdateSkippedTagName.write", source)
        self.assertNotIn("dismissedUpdate", source)

    def test_native_app_has_session_only_preferences_for_refresh_notifications_and_theme(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('"Preferences..."', source)
        self.assertIn("openPreferences", source)
        self.assertIn("NSWindow", source)
        self.assertIn("NSPopUpButton", source)
        self.assertIn("refreshModeKey", source)
        self.assertIn("notificationsEnabledKey", source)
        self.assertIn("launchAtLoginKey", source)
        self.assertIn('"Adaptive"', source)
        self.assertIn('"Every 5 minutes"', source)
        self.assertIn('"Every 10 minutes"', source)
        self.assertIn('"Launch at login disabled"', source)
        self.assertIn("login.isEnabled = false", source)
        self.assertIn('"Quota notifications"', source)
        self.assertIn("refreshPreferenceChanged", source)
        self.assertIn("notificationsPreferenceChanged", source)
        self.assertIn("launchAtLoginPreferenceChanged", source)
        self.assertIn("installLaunchAgentForCurrentApp", source)
        self.assertIn("removeLaunchAgentPlist", source)
        self.assertIn("sessionRefreshMode", source)
        self.assertIn("sessionNotificationsEnabled", source)
        self.assertNotIn("UserDefaults.standard", source)
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
        self.assertNotIn("UserDefaults.standard.set(true, forKey: firstRunSetupSeenKey)", source)

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
