import pathlib
import re
import unittest


class SignalConsoleUXTests(unittest.TestCase):
    def _first_float(self, pattern, source):
        match = re.search(pattern, source)
        self.assertIsNotNone(match, pattern)
        return float(match.group(1))

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

    def test_native_app_can_render_real_signal_console_fixtures(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "--render-signal-console-fixtures",
            "renderSignalConsoleFixtures",
            "SignalConsolePreviewTarget",
            "SignalConsolePreviewCase",
            "renderSignalConsolePanel",
            "SignalConsolePanelView(",
            "cacheDisplay(in: panel.bounds",
            "docs/design/app-rendered-signal-console",
        ]:
            self.assertIn(token, source)
        self.assertIn('DoctorCheck(title: "SSD temp", state: unavailable ? "grey" : "green"', source)

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
        self.assertIn("Today collecting", source)
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
        self.assertIn("SignalConsoleLayout", source)
        self.assertIn('"Live \\(model.liveAgeText) · refreshes every 5 min"', source)
        self.assertNotIn("drawCommandButton", source)
        self.assertNotIn('drawSectionLabel("Status"', source)
        self.assertNotIn('drawSectionLabel("Reset"', source)
        self.assertNotIn('drawDivider(y: 144)', source)

    def test_signal_console_routes_geometry_through_layout_helper(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private struct SignalConsoleLayout",
            "func splitHorizontally",
            "let layout = SignalConsoleLayout(bounds: bounds)",
            "layout.statusStripRect",
            "layout.heroCardRect",
            "layout.trendCardRect",
            "layout.reportCardRect",
            "layout.reportMetricRects",
            "layout.copyReportButtonRect",
            "layout.clearDataButtonRect",
            "layout.bottomCommandButtonRects",
        ]:
            self.assertIn(token, source)
        self.assertNotIn('addButton(title: "Copy report", frame: NSRect(x:', source)
        self.assertNotIn('addButton(title: "Clear data", frame: NSRect(x:', source)

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
        self.assertIn('clayConsoleThemeKey = "clayConsole"', source)
        self.assertIn("UserDefaults.standard.set(paperConsoleThemeKey, forKey: themePreferenceKey)", source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertIn("Signal Dark", source)
        self.assertIn("Paper Console", source)
        self.assertIn("Mono Graphite", source)
        self.assertIn("Clay Console", source)
        self.assertIn("clayConsoleTheme()", source)
        self.assertIn("#selector(themePreferenceChanged)", source)
        self.assertIn("themePopup?.selectItem(withTitle: currentSignalConsoleTheme().name)", source)

    def test_mono_graphite_theme_keeps_accents_monochrome(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func monoGraphiteTheme() -> SignalConsoleTheme", source)
        self.assertIn("monoAccent(0.86", source)
        self.assertIn("monoAccent(0.64", source)
        self.assertIn("monoAccent(0.48", source)
        self.assertIn("monoAccent(0.34", source)

    def test_paper_theme_keeps_reset_labels_readable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func paperConsoleTheme() -> SignalConsoleTheme", source)
        self.assertIn("textSecondary: NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.25, alpha: 0.96)", source)
        self.assertIn("textMuted: NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.42, alpha: 0.92)", source)
        self.assertIn('drawText("window", x: rect.minX + 14, y: rect.minY + 29, width: 48, height: 12, size: 7.4, weight: .bold, color: textSecondary)', source)
        self.assertIn('drawText("reset", x: rect.minX + 284, y: rect.minY + 7, width: 34, height: 14, size: 9.4, weight: .medium, color: textSecondary)', source)

    def test_clay_console_theme_uses_claude_command_style_palette(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func clayConsoleTheme() -> SignalConsoleTheme", source)
        self.assertIn('name: "Clay Console"', source)
        self.assertIn("panelBackground: NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.27, alpha: 1.0)", source)
        self.assertIn("panelStrongBackground: NSColor(calibratedRed: 0.26, green: 0.20, blue: 0.16, alpha: 1.0)", source)
        self.assertIn("mintAccent: NSColor(calibratedRed: 0.56, green: 0.81, blue: 0.65, alpha: 0.96)", source)
        self.assertIn("amberAccent: NSColor(calibratedRed: 0.96, green: 0.74, blue: 0.35, alpha: 0.96)", source)
        self.assertIn("case clayConsoleThemeKey:", source)
        self.assertIn("return clayConsoleTheme()", source)

    def test_all_themes_use_opaque_panel_backgrounds(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for phrase in [
            "panelBackground: NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.18, alpha: 1.0)",
            "panelBackground: NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.86, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)",
            "panelBackground: NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.27, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.26, green: 0.20, blue: 0.16, alpha: 1.0)",
            "panelBackground: monoAccent(0.05, alpha: 1.0)",
            "panelStrongBackground: monoAccent(0.12, alpha: 1.0)",
        ]:
            self.assertIn(phrase, source)
        self.assertIn("visual.blendingMode = .withinWindow", source)
        self.assertIn("NSGradient(colors: [\n            panelStrongBackground,\n            panelBackground,", source)
        self.assertNotIn("theme.trackFill.withAlphaComponent(0.32)", source)

    def test_dark_themes_keep_secondary_text_readable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("textSecondary: NSColor(calibratedRed: 0.82, green: 0.89, blue: 0.94, alpha: 0.98)", source)
        self.assertIn("textMuted: NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.76, alpha: 0.92)", source)
        self.assertIn("textSecondary: NSColor(calibratedRed: 0.75, green: 0.68, blue: 0.59, alpha: 0.96)", source)
        self.assertIn("textMuted: NSColor(calibratedRed: 0.60, green: 0.53, blue: 0.45, alpha: 0.92)", source)
        self.assertIn("textSecondary: monoAccent(0.82, alpha: 0.98)", source)
        self.assertIn("textMuted: monoAccent(0.64, alpha: 0.92)", source)

    def test_signal_console_is_compact_and_avoids_control_overlap(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("signalPopoverSize = NSSize(width: 560, height: 520)", source)
        self.assertIn("drawStatusStrip", source)
        self.assertIn("drawHealthStatusGrid", source)
        self.assertIn('addButton(title: "Run Check", frame: commandRects[2]', source)
        self.assertIn("drawHealthStatusGrid(in: layout.healthStatusGridRect)", source)
        self.assertIn("powerStatusPillRect", source)
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
        self.assertIn("let next = layout.nextRefreshPillRect", source)
        self.assertIn("drawText(model.nextRefreshText, x: next.minX + 9", source)
        self.assertNotIn('model.isRefreshing ? "now" : "5 min"', source)

    def test_power_aware_menu_bar_shows_battery_state(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private enum PowerState",
            "case battery",
            "case charging",
            "case full",
            "menuBarSystemPodRect",
            "drawMenuBarSystemPodPower",
            "drawBatteryGlyph",
            "batteryMenuBarFillColor",
            "batteryMenuBarBorderColor",
            "batteryMenuBarTextColor",
            "powerState.menuBarLabel",
            "powerPercentText()",
            "powerMenuBarText()",
            "powerState.accessibilityLabel",
            "private let menuBarSystemPodRect = NSRect(x: 184, y: 3.0, width: 112, height: 16.0)",
            "statusImageSize = NSSize(width: 300, height: 22)",
        ]:
            self.assertIn(token, source)

        for token in [
            "menuBarCompactLabel",
            "return powerPercentText()",
            "let fill = batteryMenuBarFillColor()",
            "fill.setFill()",
            "batteryMenuBarTextColor(fill: fill)",
            "batteryMenuBarIconColor(fill: fill)",
            "drawBatteryGlyph(in: iconRect, color: color, palette: palette)",
            "drawMenuBarSystemPodText(powerMenuBarText(), rect: textRect, color: textColor",
        ]:
            self.assertIn(token, source)

    def test_signal_console_has_bridge_and_power_command_cards(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "bridgeCardRect",
            "powerStatusPillRect",
            "drawBridgeCard",
            "drawPowerSignalState",
            '"Copy"',
            "Restart",
            "model.powerModeTitle",
            "model.powerModeDetail",
            "model.powerPercentText",
            "model.thoughtCoachEnabled",
        ]:
            self.assertIn(token, source)
        self.assertIn("copyThoughtCoachPairingAction", source)
        self.assertIn("restartThoughtCoachAction", source)

    def test_quota_movement_labels_include_signed_window_deltas(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func trendSignalText(values: [Int], fallback: String)", source)
        self.assertIn('let signalText = "\\(label) \\(trendSignalText(values: values, fallback: text))"', source)
        self.assertIn('drawText(signalText, x: 36', source)
        self.assertIn('return delta > 0 ? "+\\(delta)%" : "\\(delta)%"', source)
        self.assertIn('return "steady"', source)
        self.assertIn('return "collecting"', source)

    def test_quota_movement_delta_badges_do_not_look_like_buttons(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func trendDeltaText(_ values: [Int]) -> String", source)
        self.assertIn('return "stable"', source)
        self.assertIn('return delta > 0 ? "+\\(delta)%" : "\\(delta)%"', source)
        self.assertIn("drawTrendDeltaText(values: values", source)
        self.assertIn("private func drawTrendDeltaText(values: [Int], y: CGFloat)", source)
        self.assertIn("textMuted", source)
        self.assertNotIn('drawPill(text: values.isEmpty ? "--" : deltaPill(values)', source)
        self.assertNotIn("private func deltaPill(_ values: [Int])", source)

    def test_signal_console_has_clear_codex_closed_empty_state(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("drawThoughtCoachSignalState", source)
        self.assertIn('"Codex closed"', source)
        self.assertIn('"Open Codex for live quota"', source)
        self.assertIn('"Open Codex desktop once to enable live usage"', source)
        self.assertIn('"After Codex is open, Codex Gauge refreshes hands-free from the menu bar."', source)
        self.assertIn('"TC Offline"', source)

    def test_signal_console_closed_state_copy_stays_compact(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("width: unavailable ? 220 : 230, height: 16", source)
        self.assertIn('return "Open Codex for live quota"', source)
        self.assertNotIn('return "Open Codex to refresh live usage."', source)
        self.assertIn('case "LaunchAgent":', source)
        self.assertIn('case "LaunchAgent running":', source)
        self.assertIn('return "Lg"', source)

    def test_quota_movement_uses_semantic_colors(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("trendBarColor(value:", source)
        self.assertIn("trendDeltaTextColor(values:", source)
        self.assertIn("drawTrendDeltaText(values: values, y: y)", source)
        self.assertIn("let color = trendBarColor(value: value).withAlphaComponent(alpha)", source)
        self.assertIn("return quotaColor(value)", source)
        self.assertIn("return coralAccent", source)
        self.assertIn("return mintAccent", source)

    def test_usage_report_is_safe_and_honest(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("Codex Gauge Usage Report", source)
        self.assertIn("## Summary", source)
        self.assertIn("reportHeadline(summary)", source)
        self.assertIn("Quota movement estimate", source)
        self.assertIn("## Today", source)
        self.assertIn("todayUsageSummary", source)
        self.assertIn("Stale/unavailable periods", source)
        self.assertIn("nonLiveSampleCount", source)
        self.assertIn("liveSampleCount", source)
        self.assertIn("This report estimates quota movement from local snapshots.", source)
        self.assertIn("It is not token accounting, billing, or spend.", source)
        self.assertIn("NSPasteboard.general", source)
        self.assertNotIn("promptText", source)
        self.assertNotIn("responseText", source)

    def test_usage_report_is_visible_inline_and_copy_only(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("reportFiveHourMovement", source)
        self.assertIn("reportSevenDayMovement", source)
        self.assertIn("reportTodaySummary", source)
        self.assertIn("inlineUsageReportSummary", source)
        self.assertIn("localCalendar.startOfDay", source)
        self.assertIn("drawReportMetric", source)
        self.assertIn('"Copy report"', source)
        self.assertIn("NSPasteboard.general.setString(report, forType: .string)", source)
        self.assertIn("legacyUsageReportFileName", source)
        self.assertNotIn("report.write(to:", source)

    def test_usage_report_actions_do_not_overlap_source_text(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        card_height = self._first_float(r"var trendCardRect: NSRect \{\n        NSRect\(x: margin, y: 260, width: 248, height: ([0-9.]+)\)", source)
        source_offset = self._first_float(r"var reportTodayTextRect: NSRect \{\n        let card = reportCardRect\n        return NSRect\(x: card\.minX \+ innerInset, y: card\.minY \+ ([0-9.]+), width: 212, height: 12\)", source)
        source_height = self._first_float(r"var reportTodayTextRect: NSRect \{\n        let card = reportCardRect\n        return NSRect\(x: card\.minX \+ innerInset, y: card\.minY \+ 34, width: 212, height: ([0-9.]+)\)", source)
        copy_from_bottom = self._first_float(r"return NSRect\(x: card\.minX \+ 18, y: card\.maxY - ([0-9.]+), width: 96, height: 30\)", source)
        clear_from_bottom = self._first_float(r"return NSRect\(x: card\.minX \+ 122, y: card\.maxY - ([0-9.]+), width: 120, height: 30\)", source)

        source_bottom = source_offset + source_height
        button_top = card_height - max(copy_from_bottom, clear_from_bottom)
        self.assertLessEqual(source_bottom + 6, button_top)

    def test_native_app_can_clear_local_data_without_touching_auth(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("clearLocalData", source)
        self.assertIn("performClearLocalData", source)
        self.assertIn("localDataPathsForClearing", source)
        self.assertIn('"last-live-status.json"', source)
        self.assertIn('"CodexGauge-usage-report.md"', source)
        self.assertIn("runtimeLogFileName", source)
        self.assertIn("historyFileName", source)
        self.assertIn("FileManager.default.removeItem(atPath:", source)
        self.assertIn("This clears local history, last-live cache, legacy report files, and logs.", source)
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

    def test_signal_console_surfaces_optional_ssd_temperature(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("SSDTemperatureStatus", source)
        self.assertIn("ssdTemperaturePath", source)
        self.assertIn("readSSDTemperature", source)
        self.assertIn('"ssd_temperature"', source)
        self.assertIn('"SSD temp"', source)
        self.assertIn('"SSD"', source)
        self.assertIn('"SSD sensor unavailable"', source)
        self.assertIn("SSD temperature", source)
        self.assertIn("ssdTemperatureStatusLabel", source)
        self.assertIn('"Normal"', source)
        self.assertIn('"Warm"', source)
        self.assertIn('"Hot"', source)
        self.assertIn('return "\\(temperature)°C · \\(ssdTemperatureStatusLabel(status))"', source)
        self.assertIn("healthShortLabel", source)
        self.assertIn("prefix(6)", source)
        self.assertIn("safeDiagnosticsText", source)

    def test_menu_bar_ssd_temperature_can_be_hidden_without_disabling_sensor(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('showSSDTemperatureInMenuBarKey = "showSSDTemperatureInMenuBar"', source)
        self.assertIn("showSSDTemperatureCheckbox", source)
        self.assertIn("defaults.set(true, forKey: showSSDTemperatureInMenuBarKey)", source)
        self.assertIn('"Show SSD temperature in menu bar"', source)
        self.assertIn("#selector(showSSDTemperaturePreferenceChanged)", source)
        self.assertIn("showSSDTemperatureCheckbox?.state = showSSDTemperatureInMenuBar() ? .on : .off", source)
        self.assertIn("private func showSSDTemperatureInMenuBar() -> Bool", source)
        self.assertIn("UserDefaults.standard.bool(forKey: showSSDTemperatureInMenuBarKey)", source)
        self.assertIn("showSSDTemperatureInMenuBar() ? ssdTemperature : nil", source)
        self.assertIn("ssdTemperatureDoctorCheck(ssdTemperature)", source)

    def test_menu_bar_integrates_ssd_temperature_without_removing_current_quota_info(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("statusItemWidth: CGFloat = 306", source)
        self.assertIn("statusImageSize = NSSize(width: 300", source)
        self.assertIn("private let quotaRailWidth: CGFloat = 38", source)
        self.assertIn("private let resetRailWidth: CGFloat = 18", source)
        self.assertIn("private let menuBarCodexContentX: CGFloat = 30", source)
        self.assertIn("makeStatusImage(", source)
        self.assertIn("ssdTemperature: ssdTemperatureForDisplay()", source)
        self.assertIn("menuBarAccessibilitySummary", source)
        self.assertIn("ssdTemperatureDisplayText(ssdTemperatureForDisplay())", source)
        self.assertIn("menuBarTooltipTitle(title: title, status: status)", source)
        self.assertIn('parts.append("SSD \\(temperature)")', source)
        self.assertIn("button.imagePosition = .imageOnly", source)
        self.assertIn("drawMenuBarSystemPod(ssdTemperature: ssdTemperature, systemMetric: systemMetric, rect: menuBarSystemPodRect, palette: palette)", source)
        self.assertIn("private let menuBarSystemPodRect = NSRect(x: 184, y: 3.0, width: 112, height: 16.0)", source)
        self.assertIn("let fontSize: CGFloat = text.count > 3 ? 6.6 : 7.2", source)
        self.assertIn("NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)", source)
        self.assertIn("ssdTemperatureFillAlpha(status)", source)
        self.assertIn("private func drawMenuBarSystemPodTemperature", source)
        self.assertIn("private func ssdTemperatureColor", source)
        self.assertIn("drawPlanBGauge(", source)
        self.assertIn("drawPlanBRow(window: \"5h\"", source)
        self.assertIn("drawPlanBRow(window: \"7d\"", source)
        self.assertIn("drawQuotaRail(value: quotaLeft", source)
        self.assertIn("drawResetMoodLane(value: resetProgress", source)
        self.assertIn("fiveHourResetCountdown(resetEpoch)", source)
        self.assertIn("sevenDayResetCountdown(resetEpoch)", source)

    def test_reset_countdowns_use_progressive_units(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        compact_body = source.split("private func compactResetCountdown", 1)[1].split("private func clampedFraction", 1)[0]
        dropdown_body = source.split("private func resetCountdown(_ epoch: Double?)", 1)[1].split("private func infoString", 1)[0]

        self.assertIn("let minutes = max(1, Int(ceil(remaining / 60)))", compact_body)
        self.assertIn("if minutes < 60", compact_body)
        self.assertIn('return "\\(minutes)m"', compact_body)
        self.assertIn("let hours = Int(ceil(Double(minutes) / 60.0))", compact_body)
        self.assertIn("if includeDays, minutes >= 24 * 60", compact_body)
        self.assertIn('return "\\(hours)h"', compact_body)
        self.assertIn('return "\\(days)d\\(remainingHours)h"', compact_body)

        self.assertIn("let days = minutes / (24 * 60)", dropdown_body)
        self.assertIn("let remainingHours = (minutes % (24 * 60)) / 60", dropdown_body)
        self.assertIn('return remainingHours > 0 ? "in \\(days)d \\(remainingHours)h" : "in \\(days)d"', dropdown_body)
        self.assertNotIn('formatter.dateFormat = "EEE HH:mm"', dropdown_body)

    def test_menu_bar_and_signal_console_show_cpu_ram_signals(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "systemMetricHistory: [SystemMetricSample]",
            "cpuUsageText: String",
            "ramUsageText: String",
            "let retainedSystemMetricHistory = systemMetricGraphSamples(systemMetricSamples)",
            "systemMetricHistory: powerState.isBatterySaver ? [] : retainedSystemMetricHistory",
            "cpuUsageText: powerState.isBatterySaver ? \"paused\" : systemMetricPercentText(retainedSystemMetricHistory.last?.cpuPercent)",
            "ramUsageText: powerState.isBatterySaver ? \"paused\" : systemMetricPercentText(retainedSystemMetricHistory.last?.ramPercent)",
            "systemMetric: systemMetricSampleForDisplay()",
            "private let menuBarSystemPodRect",
            "drawMenuBarSystemPod(ssdTemperature: ssdTemperature, systemMetric: systemMetric, rect: menuBarSystemPodRect, palette: palette)",
            "systemMetricMenuBarText(prefix: \"C\", value: sample?.cpuPercent)",
            "systemMetricMenuBarText(prefix: \"R\", value: sample?.ramPercent)",
            "drawMenuBarSystemPodMetrics(sample: systemMetric, rect: metricsRect, palette: palette)",
            "drawSystemMetricMovementRows",
            "drawSystemMetricMovementRow(label: \"CPU\"",
            "drawSystemMetricMovementRow(label: \"RAM\"",
            "drawSystemMetricSparkline",
            "systemMetricLineColor(label: \"CPU\"",
            "systemMetricLineColor(label: \"RAM\"",
        ]:
            self.assertIn(token, source)

        self.assertIn("statusItemWidth: CGFloat = 306", source)
        self.assertIn("statusImageSize = NSSize(width: 300", source)
        self.assertIn("private let menuBarSystemPodRect = NSRect(x: 184, y: 3.0, width: 112, height: 16.0)", source)
        self.assertIn("size: 5.8", source)
        self.assertNotIn("text.count > 3 ? 5.1 : 5.6", source)

        movement_body = source.split("private func drawSystemMetricMovementRows", 1)[1].split("private func drawSystemMetricMovementRow", 1)[0]
        self.assertIn("model.cpuUsageText", movement_body)
        self.assertIn("model.ramUsageText", movement_body)

    def test_thought_coach_bridge_is_embedded_in_current_menu_bar_app(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "ThoughtCoachBridgeState",
            "Thought Coach: Ready",
            "Thought Coach: Local only",
            "Thought Coach: Offline",
            "thoughtCoachPollInterval: TimeInterval = 12",
            'URL(string: "http://127.0.0.1:8797/health")!',
            'URL(string: "http://127.0.0.1:8797/pairing")!',
            "startThoughtCoachPolling()",
            "pollThoughtCoachBridge()",
            "thoughtCoachHealthIsOK",
            "thoughtCoachPairingBridgeURL",
            "isLocalOnlyThoughtCoachBridgeURL",
            "drawThoughtCoachMenuBarChip",
            '("TC" as NSString)',
            "drawThoughtCoachSignalState",
            "Copy iPhone Pairing Payload",
            "Show Pairing Payload",
            "Restart Bridge",
            "Open Bridge Log",
            "Open Bridge Error Log",
            "thoughtCoachBridgeLaunchAgentLabelKey",
            "defaultThoughtCoachBridgeLaunchAgentLabel",
            "thoughtCoachBridgeLaunchAgentLabel()",
            "thoughtCoachProjectPath()",
            "Project folder not configured",
        ]:
            self.assertIn(token, source)

        self.assertIn("menu.popUp(positioning: nil", source)
        self.assertIn("button.action = #selector(toggleSignalConsole", source)
        self.assertNotIn("statusItem.menu = menu", source)
        self.assertNotIn("bustawind", source)
        self.assertNotIn("OPENAI_API_KEY", source)
        self.assertNotIn(".codex/auth.json", source.split("private enum ThoughtCoachBridgeState", 1)[1].split("private func safeDiagnosticsText", 1)[0])

    def test_ssd_temperature_history_samples_every_thirty_seconds_and_is_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct TemperatureSample: Codable", source)
        self.assertIn("let timeEpoch: Double?", source)
        self.assertIn("private var lastStatusImageRedrawAt: Date?", source)
        self.assertIn("private let sensorStatusImageRedrawInterval: TimeInterval = 30", source)
        self.assertIn('private let temperatureQueue = DispatchQueue(label: "app.codexgauge.temperature", qos: .utility)', source)
        self.assertIn("private var temperatureTimer: Timer?", source)
        self.assertIn("private var temperatureReadInFlight = false", source)
        self.assertIn("private var temperatureSamples: [TemperatureSample] = []", source)
        self.assertIn("private let temperatureSampleInterval: TimeInterval = 30", source)
        self.assertIn("private let chargingTemperatureSampleInterval: TimeInterval = 10", source)
        self.assertIn("private let temperatureGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("private let temperatureHistoryRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("private let temperaturePersistInterval: TimeInterval = 60", source)
        self.assertIn("private let maxTemperatureSamples = 24 * 60 * 60 / 30", source)
        self.assertIn("startTemperatureSampler(interval:", source)
        self.assertIn("sampleTemperature()", source)
        self.assertIn("Timer(timeInterval: interval, repeats: true)", source)
        self.assertIn("telemetryTemperatureSampleInterval()", source)
        self.assertIn("temperatureQueue.async", source)
        self.assertIn("DispatchQueue.main.async", source)
        self.assertIn("temperatureReadInFlight = true", source)
        self.assertIn("temperatureReadInFlight = false", source)
        self.assertIn("appendTemperatureSample(status)", source)
        self.assertIn("persistTemperatureSamplesAsync", source)
        self.assertIn("clearTemperatureHistoryAsync()", source)
        self.assertIn("temperatureC: status?.ok == true ? status?.temperatureC : nil", source)
        self.assertIn("ok: status?.ok == true && status?.temperatureC != nil", source)
        self.assertIn("retainedTemperatureSamples", source)
        self.assertIn("writeTemperatureSamples", source)
        self.assertIn("readTemperatureSamples", source)
        self.assertIn("normalizedTemperatureSamples", source)
        self.assertIn("refreshStatusImageFromCurrentState", source)
        self.assertIn("shouldRefreshSensorStatusImage", source)

        sample_body = source.split("private func sampleTemperature()", 1)[1].split("private func finishRefresh", 1)[0]
        finish_body = source.split("private func finishRefresh", 1)[1].split("private func refreshModeTitle", 1)[0]
        clear_data_body = source.split("private func performClearLocalData()", 1)[1].split("private func clearTemperatureHistoryAsync", 1)[0]
        clear_temperature_body = source.split("private func clearTemperatureHistoryAsync()", 1)[1].split("private func localDataPathsForClearing", 1)[0]
        setup_doctor_body = source.split("private func runSetupDoctorChecks()", 1)[1].split("private func doctorCheck", 1)[0]
        append_body = source.split("private func appendTemperatureSample", 1)[1].split("private func persistTemperatureSamplesAsync", 1)[0]
        persist_body = source.split("private func persistTemperatureSamplesAsync", 1)[1].split("private func writeTemperatureSamples", 1)[0]
        read_body = source.split("private func readTemperatureSamples", 1)[1].split("private func normalizedTemperatureSamples", 1)[0]
        retained_body = source.split("private func retainedTemperatureSamples", 1)[1].split("private func retainedHistorySamples", 1)[0]
        diagnostics_body = source.split("private func ssdTemperatureDiagnosticsText()", 1)[1].split("private func safeDiagnosticsText", 1)[0]
        main_update_body = sample_body.split("DispatchQueue.main.async", 1)[1]

        self.assertEqual(source.count("temperatureQueue.async"), 3)
        self.assertEqual(source.count("readSSDTemperature()"), 2)
        self.assertIn("temperatureQueue.async", sample_body)
        self.assertIn("let status = self.readSSDTemperature()", sample_body)
        self.assertNotIn("refreshSignalPopoverIfNeeded()", sample_body)
        self.assertNotIn("writeTemperatureSamples", sample_body)
        self.assertNotIn("setStatusImage(title:", sample_body)
        self.assertIn("refreshStatusImageFromCurrentState()", sample_body)
        self.assertNotIn("writeTemperatureSamples", main_update_body)
        self.assertIn("temperatureSamples = []", clear_data_body)
        self.assertIn("clearTemperatureHistoryAsync()", clear_data_body)
        self.assertIn("temperatureQueue.async", clear_temperature_body)
        self.assertIn("try? FileManager.default.removeItem(atPath: self.temperatureHistoryPath)", clear_temperature_body)
        self.assertIn("temperatureSamples.append(sample)", append_body)
        self.assertIn("temperatureSamples = retainedTemperatureSamples(temperatureSamples)", append_body)
        self.assertIn("let samplesSnapshot = temperatureSamples", append_body)
        self.assertIn("persistTemperatureSamplesAsync(samplesSnapshot)", append_body)
        self.assertIn("timeEpoch: now.timeIntervalSince1970", append_body)
        self.assertIn("temperatureC: status?.ok == true ? status?.temperatureC : nil", append_body)
        self.assertIn("ok: status?.ok == true && status?.temperatureC != nil", append_body)
        self.assertNotIn("writeTemperatureSamples", append_body)
        self.assertIn("shouldPersistTemperatureSamples(now: now)", append_body)
        self.assertIn("temperatureQueue.async", persist_body)
        self.assertIn("self.writeTemperatureSamples(samples)", persist_body)
        self.assertIn("retainedTemperatureSamples(normalizedTemperatureSamples(samples))", read_body)
        self.assertIn("sampleEpoch(sample)", retained_body)
        self.assertNotIn("isoDate(sample.time)", retained_body)
        self.assertIn("temperatureHistoryRetentionWindow", retained_body)
        self.assertIn("suffix(maxTemperatureSamples)", retained_body)
        self.assertNotIn("readSSDTemperature()", finish_body)
        self.assertNotIn("readSSDTemperature()", setup_doctor_body)
        self.assertNotIn("readSSDTemperature()", diagnostics_body)

    def test_system_metrics_sample_every_fifteen_seconds_and_are_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct SystemMetricSample: Codable", source)
        self.assertIn("let timeEpoch: Double?", source)
        self.assertIn("private var lastStatusImageRedrawAt: Date?", source)
        self.assertIn("private let sensorStatusImageRedrawInterval: TimeInterval = 30", source)
        self.assertIn("private var systemMetricsTimer: Timer?", source)
        self.assertIn("private var systemMetricSamples: [SystemMetricSample] = []", source)
        self.assertIn("private let systemMetricSampleInterval: TimeInterval = 15", source)
        self.assertIn("private let chargingSystemMetricSampleInterval: TimeInterval = 5", source)
        self.assertIn("private let systemMetricGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("private let systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("private let maxSystemMetricSamples = 24 * 60 * 60 / 15", source)
        self.assertIn('systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"', source)
        self.assertIn("private lazy var systemMetricsHistoryPath", source)
        self.assertIn("systemMetricSamples = readSystemMetricSamples()", source)
        self.assertIn("startSystemMetricsSampler(interval:", source)
        self.assertIn("systemMetricsTimer?.invalidate()", source)
        self.assertIn("writeSystemMetricSamples(systemMetricSamples)", source)
        self.assertIn("sampleSystemMetrics()", source)
        self.assertIn("Timer(timeInterval: interval, repeats: true)", source)
        self.assertIn("telemetrySystemMetricSampleInterval()", source)
        self.assertIn("readSystemMetrics()", source)
        self.assertIn("readCPUUsagePercent()", source)
        self.assertIn("readRAMUsagePercent()", source)
        self.assertIn("host_statistics", source)
        self.assertIn("host_processor_info", source)
        self.assertIn("appendSystemMetricSample", source)
        self.assertIn("retainedSystemMetricSamples", source)
        self.assertIn("systemMetricGraphSamples", source)
        self.assertIn("writeSystemMetricSamples", source)
        self.assertIn("readSystemMetricSamples", source)
        self.assertIn("normalizedSystemMetricSamples", source)
        self.assertIn("refreshStatusImageFromCurrentState", source)
        self.assertIn("shouldRefreshSensorStatusImage", source)

        clear_data_body = source.split("private func performClearLocalData()", 1)[1].split("private func clearTemperatureHistoryAsync", 1)[0]
        sample_body = source.split("private func sampleSystemMetrics()", 1)[1].split("private func readSystemMetrics", 1)[0]
        read_body = source.split("private func readSystemMetricSamples", 1)[1].split("private func normalizedSystemMetricSamples", 1)[0]
        retained_body = source.split("private func retainedSystemMetricSamples", 1)[1].split("private func retainedTemperatureSamples", 1)[0]
        self.assertIn("systemMetricSamples = []", clear_data_body)
        self.assertNotIn("setStatusImage(title:", sample_body)
        self.assertIn("refreshStatusImageFromCurrentState()", sample_body)
        self.assertIn("systemMetricsHistoryPath,", source)
        self.assertIn("retainedSystemMetricSamples(normalizedSystemMetricSamples(samples))", read_body)
        self.assertIn("sampleEpoch(sample)", retained_body)
        self.assertNotIn("isoDate(sample.time)", retained_body)
        self.assertIn("systemMetricRetentionWindow", retained_body)
        self.assertIn("suffix(maxSystemMetricSamples)", retained_body)

    def test_battery_saver_pauses_local_sensors_and_slows_quota_refresh(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("import IOKit.ps", source)
        self.assertIn("private var powerSourceRunLoopSource: CFRunLoopSource?", source)
        self.assertIn("private var isBatterySaverMode = false", source)
        self.assertIn("private let batterySaverRefreshInterval: TimeInterval = 30 * 60", source)
        self.assertIn("IOPSGetProvidingPowerSourceType", source)
        self.assertIn("kIOPSBatteryPowerValue", source)
        self.assertIn("IOPSNotificationCreateRunLoopSource", source)
        self.assertIn("startPowerSourceMonitor()", source)
        self.assertIn("stopPowerSourceMonitor()", source)
        self.assertIn("handlePowerSourceChanged()", source)
        self.assertIn("startTelemetrySamplersIfNeeded()", source)
        self.assertIn("restartTelemetrySamplersIfNeeded()", source)
        self.assertIn("stopTelemetrySamplers()", source)

        launch_body = source.split("func applicationDidFinishLaunching", 1)[1].split("func applicationWillTerminate", 1)[0]
        terminate_body = source.split("func applicationWillTerminate", 1)[1].split("func applicationShouldTerminate", 1)[0]
        next_interval_body = source.split("private func nextRefreshInterval", 1)[1].split("private func nextRefreshCountdownText", 1)[0]
        temperature_body = source.split("private func sampleTemperature()", 1)[1].split("private func finishRefresh", 1)[0]
        metrics_body = source.split("private func sampleSystemMetrics()", 1)[1].split("private func readSystemMetrics", 1)[0]
        model_body = source.split("private func signalConsoleModel()", 1)[1].split("private func signalStateTitle", 1)[0]

        self.assertIn("updateBatterySaverMode()", launch_body)
        self.assertIn("startPowerSourceMonitor()", launch_body)
        self.assertIn("startTelemetrySamplersIfNeeded()", launch_body)
        self.assertNotIn("startTemperatureSampler()", launch_body)
        self.assertNotIn("startSystemMetricsSampler()", launch_body)
        self.assertIn("stopPowerSourceMonitor()", terminate_body)
        self.assertIn("stopTelemetrySamplers()", terminate_body)
        self.assertIn("if powerState.isBatterySaver", next_interval_body)
        self.assertIn("return batterySaverRefreshInterval", next_interval_body)
        self.assertIn("guard !powerState.isBatterySaver else", temperature_body)
        self.assertIn("guard !powerState.isBatterySaver else", metrics_body)
        self.assertIn("sourcePill: sourcePillText(for:", model_body)
        self.assertIn("Battery Saver: quota only", model_body)
        self.assertIn("Codex usage refreshes every 30 min. Local sensors are paused.", model_body)
        self.assertIn("temperatureHistory: powerState.isBatterySaver ? [] : retainedTemperatureHistory", model_body)
        self.assertIn("systemMetricHistory: powerState.isBatterySaver ? [] : retainedSystemMetricHistory", model_body)
        self.assertIn("cpuUsageText: powerState.isBatterySaver ? \"paused\"", model_body)
        self.assertIn("ramUsageText: powerState.isBatterySaver ? \"paused\"", model_body)
        self.assertIn("ssdTemperatureStatusText", source)
        self.assertIn("paused on battery", source)

    def test_ssd_temperature_display_keeps_last_valid_read_briefly(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private var lastValidSSDTemperature: SSDTemperatureStatus?", source)
        self.assertIn("private var lastValidSSDTemperatureAt: Date?", source)
        self.assertIn("private let ssdTemperatureDisplayGraceInterval: TimeInterval = 10 * 60", source)
        self.assertIn("seedLastValidSSDTemperatureFromHistory()", source)
        self.assertIn("private func seedLastValidSSDTemperatureFromHistory(now: Date = Date())", source)
        self.assertIn('source: "history"', source)
        self.assertIn("private func updateLastValidSSDTemperature", source)
        self.assertIn("private func ssdTemperatureForDisplay(now: Date = Date()) -> SSDTemperatureStatus?", source)
        self.assertIn("recentTemperatureStatusFromHistory(now: now)", source)
        self.assertIn("now.timeIntervalSince(lastValidSSDTemperatureAt) <= ssdTemperatureDisplayGraceInterval", source)
        self.assertIn("lastValidSSDTemperature = status", source)
        self.assertIn("lastValidSSDTemperatureAt = date", source)
        self.assertIn("makeStatusImage(", source)
        self.assertIn("ssdTemperature: ssdTemperatureForDisplay()", source)
        self.assertIn("ssdTemperatureDisplayText(ssdTemperatureForDisplay())", source)
        self.assertIn("currentTemperatureText(status: ssdTemperatureForDisplay(), samples: retainedTemperatureHistory)", source)

        sample_body = source.split("private func sampleTemperature()", 1)[1].split("private func finishRefresh", 1)[0]
        self.assertIn("let status = self.readSSDTemperature()", sample_body)
        self.assertIn("self.ssdTemperature = status", sample_body)
        self.assertIn("self.updateLastValidSSDTemperature(status)", sample_body)
        self.assertIn("self.appendTemperatureSample(status)", sample_body)
        self.assertLess(
            sample_body.index("self.updateLastValidSSDTemperature(status)"),
            sample_body.index("self.appendTemperatureSample(status)"),
        )
        self.assertNotIn("self.lastValidSSDTemperature = status", sample_body)

    def test_signal_console_movement_shows_smooth_temperature_curve(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "temperatureHistory: [TemperatureSample]",
            "currentTemperatureText: String",
            "temperatureHistoryText: String",
            "let retainedTemperatureHistory = temperatureGraphSamples(temperatureSamples)",
            "temperatureHistory: powerState.isBatterySaver ? [] : retainedTemperatureHistory",
            "currentTemperatureText: powerState.isBatterySaver ? \"paused\" : currentTemperatureText(status: ssdTemperatureForDisplay(), samples: retainedTemperatureHistory)",
            "temperatureHistoryText: powerState.isBatterySaver ? \"paused on battery\" : temperatureHistorySummaryText(retainedTemperatureHistory)",
            '"SSD temp"',
            '"last 10m"',
            '"SSD temp unavailable"',
            'return "collecting"',
            "valid.count == 1",
            "temperatureStatusTextWidth",
            "drawTemperatureCurve",
            "drawTemperatureGraphGrid",
            "drawTemperatureEndpoint",
            "smoothedTemperaturePoints",
            "temperatureCurveColor",
            "drawTemperatureUnavailableCurve",
            "temperatureGraphSamples",
        ]:
            self.assertIn(token, source)

        summary_body = source.split("private func temperatureHistorySummaryText", 1)[1].split("private struct DoctorCheck", 1)[0]
        movement_body = source.split("private func drawTemperatureMovementRow", 1)[1].split("private func drawTemperatureCurve", 1)[0]
        snapshot_branch = source.split("if let snapshot {", 1)[1].split("let detail = lastError", 1)[0]
        unavailable_branch = source.split("let detail = lastError", 1)[1].split("private func signalStateTitle", 1)[0]

        self.assertIn('return "SSD temp unavailable"', summary_body)
        self.assertIn('return "collecting"', summary_body)
        self.assertIn('return "last 10m"', summary_body)
        self.assertIn("valid.count == 1", summary_body)
        self.assertIn("let temperatureStatusTextWidth: CGFloat = 112", source)
        self.assertIn("width: temperatureStatusTextWidth", movement_body)
        self.assertIn('drawText("10m"', movement_body)
        self.assertIn('drawText("now"', movement_body)
        self.assertIn('if model.temperatureHistoryText == "SSD temp unavailable" || model.temperatureHistoryText == "collecting"', movement_body)
        self.assertEqual(snapshot_branch.count("temperatureGraphSamples(temperatureSamples)"), 1)
        self.assertEqual(unavailable_branch.count("temperatureGraphSamples(temperatureSamples)"), 1)

    def test_signal_console_previews_derive_health_summary_from_visible_checks(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        preview_cases_body = source.split("private func signalConsolePreviewCases()", 1)[1].split("private func signalConsolePreviewModel", 1)[0]
        preview_model_body = source.split("private func signalConsolePreviewModel", 1)[1].split("private func previewTemperatureSamples", 1)[0]

        self.assertNotIn('health: "5 OK"', preview_cases_body)
        self.assertNotIn('health: "4 OK · 1 optional"', preview_cases_body)
        self.assertNotIn('health: "3 OK · 1 check"', preview_cases_body)
        self.assertIn("let doctorChecks = [", preview_model_body)
        self.assertIn("healthSummaryText: healthSummaryText(doctorChecks)", preview_model_body)
        self.assertIn('DoctorCheck(title: "SSD temp", state: unavailable ? "grey" : "green"', preview_model_body)

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
