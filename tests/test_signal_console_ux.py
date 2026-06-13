import pathlib
import unittest


class SignalConsoleUXTests(unittest.TestCase):
    def test_native_app_has_signal_console_source_state_copy(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("sourceStatusTitle", source)
        self.assertIn("sourceStatusDetail", source)
        self.assertIn('"Live data is current"', source)
        self.assertIn('"Showing last live cache"', source)
        self.assertIn('"Showing recent local snapshot"', source)
        self.assertIn('"Open Codex to refresh live usage"', source)
        self.assertIn('"Codex not reachable - showing last live"', source)
        self.assertIn('"Codex closed - showing recent local snapshot"', source)

    def test_native_app_draws_unavailable_stalled_menu_bar_state(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("drawUnavailableGauge", source)
        self.assertIn("isUnavailableStatus", source)
        self.assertIn('"Open Codex"', source)
        self.assertIn('"--"', source)
        self.assertIn("unavailableSourceColor", source)
        self.assertIn("setStatusImage(title: \"Open Codex to refresh live usage\")", source)
        self.assertIn("makeStatusImage(fiveHourLeft: nil, sevenDayLeft: nil", source)

    def test_native_app_draws_distinct_live_signal_console(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("signalRailSegments = 10", source)
        self.assertIn("drawSignalSourceRail", source)
        self.assertIn("drawSegmentedQuotaRail", source)
        self.assertIn("drawSignalSegmentedRail", source)
        self.assertIn("drawQuotaRail(value: quotaLeft", source)
        self.assertIn("drawSignalSourceRail(source: source", source)

    def test_native_app_uses_custom_signal_console_popover(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("NSPopover", source)
        self.assertIn("signalPopover", source)
        self.assertIn("toggleSignalConsole", source)
        self.assertIn("makeSignalConsoleViewController", source)
        self.assertIn("SignalConsolePanelView", source)
        self.assertIn("NSVisualEffectView", source)
        self.assertIn("popover.behavior = .transient", source)
        self.assertIn("popover.show(relativeTo: button.bounds", source)
        self.assertIn("button.action = #selector(toggleSignalConsole", source)
        self.assertNotIn("statusItem.menu = menu", source)

    def test_signal_console_popover_matches_selected_sections(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for label in [
            "Codex Gauge  •  Signal Console",
            "Source: Menu Bar",
            "Live signal",
            "Quota movement",
            "Health",
            "Usage Report",
            "this window",
            "in 24h",
            "Run Check",
            "Copy report",
            "Clear data",
            "Open Codex",
            "Quit",
        ]:
            self.assertIn(f'"{label}"', source)
        self.assertIn("drawSignalConsolePanel", source)
        self.assertIn("drawSignalHeroCard", source)
        self.assertIn("drawTrendSparkline", source)
        self.assertIn("signalConsoleModel", source)
        self.assertIn("runSetupDoctorChecks()", source)
        self.assertNotIn('drawSectionLabel("Doctor"', source)
        self.assertNotIn('drawSectionLabel("Status"', source)
        self.assertNotIn('drawSectionLabel("Reset"', source)
        self.assertNotIn('"5-hour  (last 48)"', source)
        self.assertNotIn('"7-day  (last 48)"', source)

    def test_signal_console_has_command_center_sections(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for label in [
            "Based on",
            "Usage Report",
            "Copy report",
            "Health",
            "Clear data",
        ]:
            self.assertIn(f'"{label}"', source)
        self.assertIn("24h quota summary", source)
        self.assertIn("drawTrendContext", source)
        self.assertIn("drawReportSection", source)
        self.assertIn("drawHealthRibbon", source)
        self.assertIn("healthSummaryText", source)
        self.assertIn("generateUsageReport", source)

    def test_signal_console_uses_v07_command_center_layout(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for label in [
            "Live signal",
            "next",
            "5-hour quota left",
            "7-day quota left",
            "window",
            "Quota movement",
            "last 24h",
            "local only",
            "Open Codex",
            "Refresh Now",
            "Preferences",
            "Quit",
        ]:
            self.assertIn(f'"{label}"', source)
        self.assertIn("drawQuotaWindowRow", source)
        self.assertIn("drawResetCountdownLane", source)
        self.assertIn("drawStatusStrip", source)
        self.assertIn("drawHealthRibbon", source)
        self.assertNotIn("drawCommandButton", source)
        self.assertNotIn('drawSectionLabel("Status"', source)
        self.assertNotIn('drawSectionLabel("Reset"', source)
        self.assertNotIn('drawDivider(y: 144)', source)

    def test_signal_console_uses_refined_palette_tokens(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "SignalConsoleTheme",
            "activeSignalConsoleTheme",
            "paperConsoleTheme",
            "signalDarkTheme",
            "monoGraphiteTheme",
            "panelStrongBackground",
            "panelSoftBackground",
            "mintAccent",
            "amberAccent",
            "coralAccent",
            "blueAccent",
            "mintSoft",
            "amberSoft",
            "coralSoft",
            "blueSoft",
        ]:
            self.assertIn(token, source)
        self.assertIn("quotaFillGradient(value:", source)
        self.assertIn("resetLaneGradient", source)

    def test_signal_console_supports_selectable_themes_with_paper_default(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('themePreferenceKey = "signalConsoleTheme"', source)
        self.assertIn('paperConsoleThemeKey = "paperConsole"', source)
        self.assertIn('signalDarkThemeKey = "signalDark"', source)
        self.assertIn('monoGraphiteThemeKey = "monoGraphite"', source)
        self.assertIn("UserDefaults.standard.set(paperConsoleThemeKey, forKey: themePreferenceKey)", source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertIn("Signal Dark", source)
        self.assertIn("Paper Console", source)
        self.assertIn("Mono Graphite", source)
        self.assertIn("#selector(themePreferenceChanged)", source)
        self.assertIn("themePopup?.selectItem(withTitle: currentSignalConsoleTheme().name)", source)

    def test_mono_graphite_theme_keeps_accents_monochrome(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func monoGraphiteTheme() -> SignalConsoleTheme", source)
        self.assertIn("monoAccent(0.86", source)
        self.assertIn("monoAccent(0.64", source)
        self.assertIn("monoAccent(0.48", source)
        self.assertIn("monoAccent(0.34", source)

    def test_signal_console_is_compact_and_avoids_control_overlap(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("signalPopoverSize = NSSize(width: 560, height: 560)", source)
        self.assertIn("drawStatusStrip", source)
        self.assertIn("drawHealthStatusGrid", source)
        self.assertIn('addButton(title: "Run Check", frame: NSRect(x: 450, y: 440, width: 82, height: 30)', source)
        self.assertIn('drawHealthStatusGrid(in: NSRect(x: rect.minX + 118, y: rect.minY + 14, width: 300, height: 30)', source)
        self.assertNotIn("drawCommandButton", source)
        self.assertNotIn("drawBottomCommands", source)
        self.assertNotIn("signalPopoverSize = NSSize(width: 640, height: 750)", source)

    def test_signal_console_shows_real_next_refresh_countdown(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("let nextRefreshText: String", source)
        self.assertIn("private var nextRefreshAt: Date?", source)
        self.assertIn("private var popoverCountdownTimer: Timer?", source)
        self.assertIn("nextRefreshCountdownText(now: now)", source)
        self.assertIn("nextRefreshAt = Date().addingTimeInterval(interval)", source)
        self.assertIn("startPopoverCountdownTimer()", source)
        self.assertIn("stopPopoverCountdownTimer()", source)
        self.assertIn('drawText(model.nextRefreshText, x: rect.maxX - 58', source)
        self.assertNotIn('model.isRefreshing ? "now" : "5 min"', source)

    def test_quota_movement_labels_include_signed_window_deltas(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func trendSignalText(values: [Int], fallback: String)", source)
        self.assertIn('let signalText = "\\(label) \\(trendSignalText(values: values, fallback: text))"', source)
        self.assertIn('drawText(signalText, x: 36', source)
        self.assertIn('return delta > 0 ? "+\\(delta)%" : "\\(delta)%"', source)
        self.assertIn('return "steady"', source)
        self.assertIn('return "collecting"', source)

    def test_signal_console_has_clear_codex_closed_empty_state(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("drawClosedSignalState", source)
        self.assertIn('"Codex closed"', source)
        self.assertIn('"Open Codex to refresh live usage"', source)
        self.assertIn('"No live quota yet"', source)
        self.assertIn("if model.isUnavailable {", source)

    def test_quota_movement_uses_semantic_colors(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("trendBarColor(value:", source)
        self.assertIn("trendDeltaPillColor(values:", source)
        self.assertIn("drawPill(text: values.isEmpty ? \"--\" : deltaPill(values), rect: NSRect(x: 226, y: y - 3, width: 26, height: 22), color: trendDeltaPillColor(values: values))", source)
        self.assertIn("let color = trendBarColor(value: value).withAlphaComponent(alpha)", source)
        self.assertIn("return quotaColor(value)", source)
        self.assertIn("return coralSoft", source)
        self.assertIn("return mintSoft", source)

    def test_usage_report_is_safe_and_honest(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("Codex Gauge Usage Report", source)
        self.assertIn("Quota movement estimate", source)
        self.assertIn("This report estimates quota movement from local snapshots.", source)
        self.assertIn("It is not token accounting, billing, or spend.", source)
        self.assertIn("NSPasteboard.general", source)
        self.assertNotIn("promptText", source)
        self.assertNotIn("responseText", source)

    def test_usage_report_is_visible_inline_and_copy_only(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("reportFiveHourMovement", source)
        self.assertIn("reportSevenDayMovement", source)
        self.assertIn("reportSourceMix", source)
        self.assertIn("inlineUsageReportSummary", source)
        self.assertIn("drawReportMetric", source)
        self.assertIn('"Copy report"', source)
        self.assertIn("NSPasteboard.general.setString(report, forType: .string)", source)
        self.assertNotIn("CodexGauge-usage-report.md", source)
        self.assertNotIn("report.write(to:", source)

    def test_native_app_can_clear_local_data_without_touching_auth(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("clearLocalData", source)
        self.assertIn("performClearLocalData", source)
        self.assertIn("localDataPathsForClearing", source)
        self.assertIn('"last-live-status.json"', source)
        self.assertIn("runtimeLogFileName", source)
        self.assertIn("historyFileName", source)
        self.assertIn("FileManager.default.removeItem(atPath:", source)
        self.assertIn("This clears local history, last-live cache, and logs.", source)
        self.assertNotIn('removeItem(atPath: NSHomeDirectory() + "/.codex/auth.json"', source)
        self.assertNotIn("browser cookies path", source.lower())

    def test_native_app_stores_bounded_safe_history(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("CodexGauge-history.json", source)
        self.assertIn("maxHistorySamples = 720", source)
        self.assertIn("historyRetentionWindow: TimeInterval = 48 * 60 * 60", source)
        self.assertIn("appendHistorySample", source)
        self.assertIn("trendSummary", source)
        self.assertIn("HistorySample", source)
        self.assertIn("historyDate", source)
        self.assertIn("historySamples(since:", source)
        self.assertIn("currentFiveHourWindowSamples", source)
        self.assertIn("24 * 60 * 60", source)
        self.assertIn("fiveHourLeft", source)
        self.assertIn("sevenDayLeft", source)
        self.assertNotIn("promptText", source)
        self.assertNotIn("responseText", source)

    def test_native_app_has_setup_doctor_and_safe_diagnostics(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("openSetupDoctor", source)
        self.assertIn("runSetupDoctorChecks", source)
        self.assertIn('"Setup Doctor"', source)
        for label in [
            "Codex app found",
            "Helper works",
            "Live data available",
            "LaunchAgent running",
            "Notifications permission",
        ]:
            self.assertIn(label, source)

        self.assertIn("copyDiagnostics", source)
        self.assertIn("safeDiagnosticsText", source)
        self.assertIn('"Copy Diagnostics"', source)
        self.assertIn('"Test Refresh"', source)
        for blocked in [
            "browser cookies",
            "~/.codex/auth.json",
            "Session file contents",
            "Runtime logs",
        ]:
            self.assertIn(blocked, source)

    def test_signal_console_docs_are_public_safe(self):
        spec = pathlib.Path("docs/design/codex-gauge-signal-console-v0.6-design.md").read_text()
        image = pathlib.Path("docs/design/codex-gauge-signal-console-v0.6.png")
        plan = pathlib.Path("docs/design/codex-gauge-signal-console-v0.6-implementation-plan.md").read_text()

        self.assertTrue(image.exists())
        self.assertLess(image.stat().st_size, 2_000_000)
        self.assertIn("Signal Console", spec)
        self.assertIn("Open Codex to refresh live usage", spec)
        self.assertIn("Do not store prompts", spec)
        self.assertIn("Do not push", plan)
        self.assertNotIn("/Users/", spec + plan)
        self.assertNotIn("bustawind", (spec + plan).lower())


if __name__ == "__main__":
    unittest.main()
