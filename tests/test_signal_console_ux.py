import pathlib
import re
import unittest


class SignalConsoleUXTests(unittest.TestCase):
    def _first_float(self, pattern, source):
        match = re.search(pattern, source)
        self.assertIsNotNone(match, pattern)
        return float(match.group(1))

    def _swift_function_body(self, source, signature):
        start = source.find(signature)
        self.assertNotEqual(start, -1, signature)
        brace_start = source.find("{", start)
        self.assertNotEqual(brace_start, -1, signature)
        depth = 0
        for index in range(brace_start, len(source)):
            char = source[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return source[brace_start + 1:index]
        self.fail(f"Could not extract Swift function body for {signature}")

    def _swift_rect_constant(self, source, name):
        pattern = rf"{name} = NSRect\(x: ([0-9.]+), y: ([0-9.]+), width: ([0-9.]+), height: ([0-9.]+)\)"
        match = re.search(pattern, source)
        self.assertIsNotNone(match, name)
        x, y, width, height = (float(value) for value in match.groups())
        return {"x": x, "y": y, "width": width, "height": height, "max_x": x + width}

    def test_native_app_has_signal_console_source_state_copy(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("sourceStatusTitle", source)
        self.assertIn("sourceStatusDetail", source)
        self.assertIn('"Live data is current"', source)
        self.assertIn('"Non-live fallback disabled in app"', source)
        self.assertIn('"Snapshot fallback disabled in app"', source)
        self.assertIn('"Open Codex to refresh live usage"', source)
        self.assertIn('"Zero persistence keeps no cached fallback in app mode"', source)
        self.assertIn('"Zero persistence keeps no local snapshot fallback in app mode"', source)

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
        self.assertIn("drawMenuBarUsagePercentBar(value: value", source)
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
            "Usage summary",
            "this window",
            "in 24h",
            "Run Check",
            "Copy summary",
            "Clear legacy",
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
            "Usage summary",
            "Copy summary",
            "Health",
            "Clear legacy",
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

    def test_signal_console_supports_session_only_selectable_themes(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('blueCeramicThemeKey = "blueCeramic"', source)
        self.assertIn('porcelainLabThemeKey = "porcelainLab"', source)
        self.assertIn('paperConsoleThemeKey = "paperConsole"', source)
        self.assertIn('signalDarkThemeKey = "signalDark"', source)
        self.assertIn('monoGraphiteThemeKey = "monoGraphite"', source)
        self.assertIn("private var sessionSignalConsoleThemeKey = blueCeramicThemeKey", source)
        self.assertIn("sessionSignalConsoleThemeKey = key", source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertIn("Blue Ceramic", source)
        self.assertIn("Signal Dark", source)
        self.assertIn("Porcelain Lab", source)
        self.assertIn("Mono Graphite", source)
        self.assertIn("#selector(themePreferenceChanged)", source)
        self.assertIn("themePopup?.selectItem(withTitle: currentSignalConsoleTheme().name)", source)
        self.assertNotIn("UserDefaults.standard", source)

    def test_mono_graphite_theme_keeps_accents_monochrome(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func monoGraphiteTheme() -> SignalConsoleTheme", source)
        self.assertIn("monoAccent(0.86", source)
        self.assertIn("monoAccent(0.64", source)
        self.assertIn("monoAccent(0.48", source)
        self.assertIn("monoAccent(0.34", source)

    def test_porcelain_theme_keeps_reset_labels_readable(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func porcelainLabTheme() -> SignalConsoleTheme", source)
        self.assertIn("textSecondary: NSColor(calibratedRed: 0.19, green: 0.28, blue: 0.31, alpha: 0.96)", source)
        self.assertIn("textMuted: NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.53, alpha: 0.92)", source)
        self.assertIn('drawText("window", x: rect.minX + 14, y: rect.minY + 35, width: 48, height: 14, size: 8, weight: .bold, color: textSecondary)', source)
        self.assertIn('drawText("reset", x: rect.minX + 288, y: rect.minY + 12, width: 34, height: 16, size: 10, weight: .medium, color: textSecondary)', source)

    def test_blue_ceramic_is_default_zero_persistence_theme(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn('blueCeramicThemeKey = "blueCeramic"', source)
        self.assertIn("private var sessionSignalConsoleThemeKey = blueCeramicThemeKey", source)
        self.assertIn("private func blueCeramicTheme() -> SignalConsoleTheme", source)
        self.assertIn('name: "Blue Ceramic"', source)
        self.assertIn("drawPanelAccentRail()", source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertNotIn("themePreferenceKey", source)
        self.assertNotIn("UserDefaults.standard", source)

    def test_blue_ceramic_is_default_redesign_theme(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            'blueCeramicThemeKey = "blueCeramic"',
            "private var sessionSignalConsoleThemeKey = blueCeramicThemeKey",
            "private func blueCeramicTheme() -> SignalConsoleTheme",
            'name: "Blue Ceramic"',
            "panelBackground: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0)",
            "mintAccent: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96)",
            "amberAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96)",
            "coralAccent: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96)",
            "blueAccent: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96)",
        ]:
            self.assertIn(token, source)

        self.assertIn('"Blue Ceramic"', source)
        self.assertIn("currentSignalConsoleTheme()", source)
        self.assertNotIn("UserDefaults.standard", source)

    def test_battery_uses_blue_semantics_not_amber_in_power_saver(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private func batterySignalColor(_ status: BatteryStatus?) -> NSColor",
            "private func batterySoftFillColor(_ status: BatteryStatus?) -> NSColor",
            "return blueAccent",
            "return theme.blueAccent",
            "Battery mode",
            "Refresh \\(minutes)m",
        ]:
            self.assertIn(token, source)

        battery_color_body = self._swift_function_body(source, "private func batterySignalColor(_ status: BatteryStatus?) -> NSColor")
        self.assertIn("if let percent = status.percent, percent < 15", battery_color_body)
        self.assertIn("return coralAccent", battery_color_body)
        self.assertIn("return blueAccent", battery_color_body)
        self.assertNotIn("return amberAccent", battery_color_body)

        menu_battery_body = self._swift_function_body(source, "private func batteryMenuBarColor(_ status: BatteryStatus?, palette: GaugePalette) -> NSColor")
        self.assertIn("return morandiMenuBarMist()", menu_battery_body)
        self.assertNotIn("return warningQuotaColor", menu_battery_body)

    def test_signal_console_has_dedicated_battery_mode_strip(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "var batteryModeStripRect: NSRect",
            "drawBatteryModeStrip()",
            "drawSignalHeroCard()",
            '"Battery mode"',
            '"Power Saver active"',
            "model.refreshCadenceText",
            "blueSoft",
        ]:
            self.assertIn(token, source)

        panel_body = self._swift_function_body(source, "private func drawSignalConsolePanel()")
        for call in [
            "drawSignalHeroCard()",
            "drawBatteryModeStrip()",
            "drawTrendSection()",
        ]:
            self.assertIn(call, panel_body)
        self.assertLess(panel_body.index("drawSignalHeroCard()"), panel_body.index("drawBatteryModeStrip()"))
        self.assertLess(panel_body.index("drawBatteryModeStrip()"), panel_body.index("drawTrendSection()"))

    def test_blue_ceramic_uses_selected_instrument_panel_visual_language(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "drawCircuitLogoMark",
            "drawCircuitTraceMotif",
            "drawInstrumentDivider",
            "drawUtilitySidebar",
            "drawUtilityCircuitMotif",
            '"General"',
            '"Appearance"',
            '"Signals"',
            '"Updates"',
            '"Battery"',
            '"Storage"',
            '"Advanced"',
            '"About"',
        ]:
            self.assertIn(token, source)

        header_body = self._swift_function_body(source, "private func drawHeader()")
        self.assertIn("drawCircuitLogoMark", header_body)

        battery_body = self._swift_function_body(source, "private func drawBatteryModeStrip()")
        self.assertIn("drawCircuitTraceMotif", battery_body)
        self.assertIn("drawChevron", battery_body)

        quota_row_body = self._swift_function_body(source, "private func drawQuotaWindowRow(window: String, label: String, value: Int?, resetText: String, resetProgress: Int?, rect: NSRect)")
        self.assertIn("drawInstrumentRowBaseline", quota_row_body)
        self.assertNotIn("drawRoundedRect(rect", quota_row_body)

        instrument_body = self._swift_function_body(source, "private func drawInstrumentRowBaseline(_ rect: NSRect)")
        self.assertNotIn(".fill()", instrument_body)

        background_body = self._swift_function_body(source, "private func drawPanelBackground()")
        self.assertNotIn("drawCircuitTraceMotif", background_body)

        self.assertNotIn("drawText(model.batteryStatusText", battery_body)

        preferences_body = self._swift_function_body(source, "private func makePreferencesWindow() -> NSWindow")
        self.assertIn("width: 640, height: 460", preferences_body)
        self.assertIn("drawUtilitySidebar", source)
        self.assertIn('popup.addItems(withTitles: ["Adaptive", "Every 5 minutes", "Every 10 minutes"])', preferences_body)
        self.assertIn("@objc private func resetSessionPreferences()", source)
        self.assertIn("Reset to Defaults...", preferences_body)
        self.assertNotIn("notifications.frame = NSRect(x: labelX, y: 164", preferences_body)
        self.assertNotIn("updates.frame = NSRect(x: labelX, y: 164", preferences_body)
        self.assertNotIn("let testRefresh = NSButton", preferences_body)

        refresh_title_body = self._swift_function_body(source, "private func refreshTitle(for mode: String) -> String")
        self.assertIn('return "Every 5 minutes"', refresh_title_body)
        self.assertIn('return "Every 10 minutes"', refresh_title_body)

    def test_all_themes_use_opaque_panel_backgrounds(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for phrase in [
            "panelBackground: NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.18, alpha: 1.0)",
            "panelBackground: NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.00, alpha: 1.0)",
            "panelStrongBackground: NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.97, alpha: 1.0)",
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
        self.assertIn("textSecondary: monoAccent(0.82, alpha: 0.98)", source)
        self.assertIn("textMuted: monoAccent(0.64, alpha: 0.92)", source)

    def test_signal_console_is_compact_and_avoids_control_overlap(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("signalPopoverSize = NSSize(width: 560, height: 560)", source)
        self.assertIn("drawStatusStrip", source)
        self.assertIn("drawHealthStatusGrid", source)
        self.assertIn('addButton(title: "Run Check", frame: layout.runCheckButtonRect', source)
        self.assertIn("drawHealthStatusGrid(in: layout.healthStatusGridRect)", source)
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
        self.assertIn("drawText(model.nextRefreshText, x: next.minX + 46", source)
        self.assertNotIn('model.isRefreshing ? "now" : "5 min"', source)

    def test_quota_movement_labels_include_signed_window_deltas(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private func trendSignalText(values: [Int], fallback: String)", source)
        self.assertIn('let signalText = "\\(label) \\(trendSignalText(values: values, fallback: text))"', source)
        self.assertIn("let labelX = card.minX + 16", source)
        self.assertIn('return delta > 0 ? "+\\(delta)%" : "\\(delta)%"', source)
        self.assertIn('return "steady"', source)
        self.assertIn('return "collecting"', source)

    def test_movement_panel_uses_card_relative_non_overlapping_grid(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        trend_body = self._swift_function_body(source, "private func drawTrendSection()")
        self.assertIn('drawText("last 24h", x: card.minX + 104', trend_body)
        self.assertNotIn('drawText("last 24h", x: card.maxX - 62', trend_body)
        self.assertIn('drawTrendRow(label: "5h", text: model.fiveHourTrendText, values: model.fiveHourHistory, y: card.minY + 52)', trend_body)
        self.assertIn('drawTrendRow(label: "7d", text: model.sevenDayTrendText, values: model.sevenDayHistory, y: card.minY + 73)', trend_body)

        trend_row_body = self._swift_function_body(source, "private func drawTrendRow(label: String, text: String, values: [Int], y: CGFloat)")
        self.assertIn("let layout = SignalConsoleLayout(bounds: bounds)", trend_row_body)
        self.assertIn("let labelX = card.minX + 16", trend_row_body)
        self.assertIn("let sparklineRect = NSRect(x: card.minX + 84", trend_row_body)
        self.assertNotIn("x: 36", trend_row_body)
        self.assertNotIn("NSRect(x: 94", trend_row_body)
        self.assertNotIn("x: 150", trend_row_body)

        battery_row_body = self._swift_function_body(source, "private func drawBatteryStatusRow(in card: NSRect)")
        self.assertIn("let chip = NSRect(x: card.maxX - 96, y: card.minY + 13, width: 80, height: 20)", battery_row_body)
        self.assertNotIn("card.maxY - 68", battery_row_body)

        temperature_row_body = self._swift_function_body(source, "private func drawTemperatureMovementRow(in card: NSRect)")
        self.assertIn("y: card.minY + 92", temperature_row_body)
        self.assertNotIn("card.maxY - 35", temperature_row_body)

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

        self.assertIn("drawClosedSignalState", source)
        self.assertIn('"Codex closed"', source)
        self.assertIn('"Open Codex for live quota"', source)
        self.assertIn('"Open Codex desktop once to enable live usage"', source)
        self.assertIn('"After Codex is open, Codex Gauge refreshes hands-free from the menu bar."', source)
        self.assertIn('"No live quota yet"', source)
        self.assertIn("if model.isUnavailable {", source)

    def test_signal_console_closed_state_copy_stays_compact(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("width: unavailable ? 176 : 268", source)
        self.assertIn('return "Open Codex for live quota"', source)
        self.assertNotIn('return "Open Codex to refresh live usage."', source)
        self.assertIn('case "Session storage":', source)
        self.assertIn('return "Store"', source)

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
        self.assertIn('"Copy summary"', source)
        self.assertIn("NSPasteboard.general.setString(report, forType: .string)", source)
        self.assertIn("legacyUsageReportFileName", source)
        self.assertNotIn("report.write(to:", source)

    def test_usage_report_actions_do_not_overlap_source_text(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        card_height = self._first_float(r"var trendCardRect: NSRect \{\n        NSRect\(x: margin, y: 328, width: 248, height: ([0-9.]+)\)", source)
        source_offset = self._first_float(r"var reportTodayTextRect: NSRect \{\n        let card = reportCardRect\n        return NSRect\(x: card\.minX \+ innerInset, y: card\.minY \+ ([0-9.]+), width: 212, height: 12\)", source)
        source_height = self._first_float(r"var reportTodayTextRect: NSRect \{\n        let card = reportCardRect\n        return NSRect\(x: card\.minX \+ innerInset, y: card\.minY \+ 34, width: 212, height: ([0-9.]+)\)", source)
        copy_from_bottom = self._first_float(r"return NSRect\(x: card\.minX \+ 18, y: card\.maxY - ([0-9.]+), width: 108, height: 30\)", source)
        clear_from_bottom = self._first_float(r"return NSRect\(x: card\.minX \+ 136, y: card\.maxY - ([0-9.]+), width: 106, height: 30\)", source)

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
        self.assertIn("Clear legacy data", source)
        self.assertIn("old history, last-live cache, report, log, and LaunchAgent files", source)
        self.assertNotIn('removeItem(atPath: NSHomeDirectory() + "/.codex/auth.json"', source)
        self.assertNotIn("browser cookies path", source.lower())

    def test_native_app_keeps_quota_summary_live_only(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("CodexGauge-history.json", source)
        self.assertIn("maxHistorySamples = 720", source)
        self.assertIn("historyRetentionWindow: TimeInterval = 48 * 60 * 60", source)
        self.assertIn("liveUsageSummaryText", source)
        self.assertIn("Storage mode: Zero persistence", source)
        self.assertIn("trendSummary", source)
        self.assertIn("HistorySample", source)
        self.assertIn("historyDate", source)
        self.assertIn("historySamples(since:", source)
        self.assertIn("currentFiveHourWindowSamples", source)
        self.assertIn("24 * 60 * 60", source)
        self.assertIn("fiveHourLeft", source)
        self.assertIn("sevenDayLeft", source)
        self.assertIn("private func readHistorySamples() -> [HistorySample] {\n        []\n    }", source)
        self.assertNotIn("appendHistorySample", source)
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
            "Session storage",
            "Notifications permission",
        ]:
            self.assertIn(label, source)

        self.assertIn("copyDiagnostics", source)
        self.assertIn("safeDiagnosticsText", source)
        self.assertIn('"Copy Diagnostics"', source)
        self.assertIn('"Refresh Now"', source)
        for blocked in [
            "browser cookies",
            "~/.codex/auth.json",
            "session file contents",
            "runtime logs",
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
        self.assertIn('"Show SSD temperature in menu bar"', source)
        self.assertIn("#selector(showSSDTemperaturePreferenceChanged)", source)
        self.assertIn("showSSDTemperatureCheckbox?.state = showSSDTemperatureInMenuBar() ? .on : .off", source)
        self.assertIn("private func showSSDTemperatureInMenuBar() -> Bool", source)
        self.assertIn("sessionShowSSDTemperatureInMenuBar", source)
        self.assertNotIn("UserDefaults.standard.bool(forKey: showSSDTemperatureInMenuBarKey)", source)
        make_status_body = self._swift_function_body(
            source,
            "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage",
        )
        self.assertNotIn("showSSDTemperatureInMenuBar()", make_status_body)
        self.assertNotIn("drawMenuBarSSDTemperature", make_status_body)
        self.assertIn("ssdTemperatureDoctorCheck(ssdTemperature)", source)

    def test_menu_bar_status_item_stays_compact_enough_to_remain_visible(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        status_width = self._first_float(r"statusItemWidth: CGFloat = ([0-9.]+)", source)
        image_width = self._first_float(r"statusImageSize = NSSize\(width: ([0-9.]+)", source)

        self.assertLessEqual(status_width, 166)
        self.assertLessEqual(image_width, 160)

        for rect_name in [
            "menuBarUsagePercentRect",
            "menuBarRefreshCountdownRect",
        ]:
            rect = self._swift_rect_constant(source, rect_name)
            self.assertLessEqual(rect["max_x"], image_width - 2, rect_name)

    def test_menu_bar_focuses_usage_percentage_and_refresh_countdown(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("statusItemWidth: CGFloat = 164", source)
        self.assertIn("statusImageSize = NSSize(width: 158", source)
        self.assertIn("private let menuBarUsagePercentRect = NSRect(x: 7", source)
        self.assertIn("private let menuBarRefreshCountdownRect = NSRect(x: 101", source)
        self.assertIn("private let quotaRailWidth: CGFloat = 42", source)
        self.assertIn("makeStatusImage(", source)
        self.assertIn("ssdTemperature: ssdTemperatureForDisplay()", source)
        self.assertIn("menuBarAccessibilitySummary", source)
        self.assertIn("ssdTemperatureDisplayText(ssdTemperatureForDisplay())", source)
        self.assertIn("menuBarTooltipTitle(title: title, status: status)", source)
        self.assertIn('parts.append("SSD \\(temperature)")', source)
        self.assertIn("button.imagePosition = .imageOnly", source)
        self.assertIn("drawPlanBGauge(", source)
        self.assertIn("drawMenuBarUsagePercentBars(", source)
        self.assertIn("drawMenuBarUsagePercentRow(window: \"5h\"", source)
        self.assertIn("drawMenuBarUsagePercentRow(window: \"7d\"", source)
        self.assertIn("drawMenuBarUsagePercentBar(value:", source)
        self.assertIn("drawMenuBarRefreshCountdown(", source)
        self.assertIn("fiveHourResetCountdown(status.fiveHourReset)", source)
        self.assertIn("sevenDayResetCountdown(status.sevenDayReset)", source)

        make_status_body = self._swift_function_body(
            source,
            "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage"
        )
        self.assertNotIn("drawMenuBarSSDTemperature", make_status_body)
        self.assertNotIn("drawMenuBarSystemMetricStrip", make_status_body)
        self.assertNotIn("drawMenuBarBatteryModeInfo", make_status_body)
        self.assertNotIn("drawMenuBarBattery(status:", make_status_body)

        refresh_body = self._swift_function_body(
            source,
            "private func drawMenuBarRefreshCountdown(fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette)"
        )
        self.assertIn("fiveHourResetCountdown(fiveHourReset)", refresh_body)
        self.assertIn("sevenDayResetCountdown(sevenDayReset)", refresh_body)
        self.assertIn("drawMenuBarCountdownPill(text: fiveHourText", refresh_body)
        self.assertIn("drawMenuBarCountdownPill(text: sevenDayText", refresh_body)
        self.assertIn("(resetText as NSString).draw", source)

    def test_menu_bar_uses_minimal_morandi_countdown_design(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "drawMenuBarMinimalMorandiPill",
            "drawMenuBarMorandiDivider",
            "morandiMenuBarShellTop",
            "morandiMenuBarSage",
            "morandiMenuBarMist",
            "morandiMenuBarClay",
            "drawMenuBarChrome",
        ]:
            self.assertIn(token, source)

        signature = "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage"
        make_status_body = self._swift_function_body(source, signature)
        self.assertIn("drawMenuBarChrome(source: source, nonLiveMode: nonLiveMode, palette: palette)", make_status_body)
        self.assertLess(make_status_body.index("drawMenuBarChrome"), make_status_body.index("drawSignalSourceRail"))
        self.assertNotIn("palette.background.setFill()", make_status_body)
        self.assertNotIn("frame.fill()", make_status_body)

        chrome_body = self._swift_function_body(source, "private func drawMenuBarChrome(source: String?, nonLiveMode: Bool, palette: GaugePalette)")
        self.assertIn("drawMenuBarMinimalMorandiPill", chrome_body)
        self.assertIn("drawMenuBarMorandiDivider", chrome_body)
        self.assertIn("for x in [96]", chrome_body)
        self.assertNotIn("drawMenuBarCircuitAccent", chrome_body)
        self.assertNotIn("drawMenuBarZoneSeparators", chrome_body)

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
            "systemMetricHistory: retainedSystemMetricHistory",
            "cpuUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.cpuPercent)",
            "ramUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.ramPercent)",
            "systemMetric: systemMetricSampleForDisplay()",
            "systemMetricMenuBarText(prefix: \"C\", value: sample?.cpuPercent)",
            "systemMetricMenuBarText(prefix: \"R\", value: sample?.ramPercent)",
            "drawSystemMetricMovementRows",
            "drawSystemMetricMovementRow(label: \"CPU\"",
            "drawSystemMetricMovementRow(label: \"RAM\"",
            "drawSystemMetricSparkline",
            "systemMetricLineColor(label: \"CPU\"",
            "systemMetricLineColor(label: \"RAM\"",
        ]:
            self.assertIn(token, source)

        self.assertIn("statusItemWidth: CGFloat = 164", source)
        self.assertIn("statusImageSize = NSSize(width: 158", source)
        make_status_body = self._swift_function_body(
            source,
            "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage",
        )
        self.assertNotIn("drawMenuBarSystemMetricStrip", make_status_body)
        self.assertIn("let fontSize: CGFloat = 6.3", source)
        self.assertNotIn("text.count > 3 ? 5.1 : 5.6", source)

        movement_body = source.split("private func drawSystemMetricMovementRows", 1)[1].split("private func drawSystemMetricMovementRow", 1)[0]
        self.assertIn("model.cpuUsageText", movement_body)
        self.assertIn("model.ramUsageText", movement_body)

    def test_power_saver_pauses_background_hardware_sampling_on_battery(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "configureHardwareSamplersForPowerState()",
            "private func configureHardwareSamplersForPowerState()",
            "private func hardwareBackgroundSamplingAllowed() -> Bool",
            "return hardwareSignalsVisible()",
            "powerPolicy.hardwareSignalsVisible(powerSaverActive: powerSaverActive())",
            "private func sampleHardwareAfterRefreshIfAllowed()",
            "private func startVisibleTemperatureSamplerIfNeeded()",
            "private func stopVisibleTemperatureSampler()",
            "startVisibleTemperatureSamplerIfNeeded()",
            "stopVisibleTemperatureSampler()",
        ]:
            self.assertIn(token, source)

        launch_body = source.split("func applicationDidFinishLaunching", 1)[1].split("func applicationWillTerminate", 1)[0]
        self.assertIn("configureHardwareSamplersForPowerState()", launch_body)
        self.assertNotIn("startTemperatureSampler()", launch_body)
        self.assertNotIn("startSystemMetricsSampler()", launch_body)

        configure_body = source.split("private func configureHardwareSamplersForPowerState()", 1)[1].split("private func hardwareBackgroundSamplingAllowed", 1)[0]
        self.assertIn("if hardwareBackgroundSamplingAllowed()", configure_body)
        self.assertIn("startSystemMetricsSampler()", configure_body)
        self.assertIn("stopTemperatureSampler()", configure_body)
        self.assertIn("stopSystemMetricsSampler()", configure_body)
        self.assertNotIn("startTemperatureSampler()", configure_body)

        finish_body = self._swift_function_body(source, "private func finishRefresh(status: Int32, output: String, errorOutput: String)")
        self.assertIn("sampleHardwareAfterRefreshIfAllowed()", finish_body)
        self.assertNotIn("sampleTemperature()", finish_body)

        post_refresh_sample_body = self._swift_function_body(source, "private func sampleHardwareAfterRefreshIfAllowed()")
        self.assertIn("guard hardwareSignalsVisible() else", post_refresh_sample_body)
        self.assertIn("sampleTemperature()", post_refresh_sample_body)

        visible_sampler_body = self._swift_function_body(source, "private func startVisibleTemperatureSamplerIfNeeded()")
        self.assertIn("stopVisibleTemperatureSampler()", visible_sampler_body)
        self.assertIn("guard hardwareSignalsVisible() else", visible_sampler_body)
        self.assertIn("startTemperatureSampler()", visible_sampler_body)
        self.assertNotIn("sampleSystemMetrics()", visible_sampler_body)
        self.assertNotIn("temporaryHardwareSamplerTimer", source)
        self.assertNotIn("private func sampleHardwareForOpenSignalConsole", source)
        self.assertNotIn("powerSaverHardwareSampleInterval", source)

        show_popover_body = self._swift_function_body(source, "private func showSignalConsolePopover()")
        self.assertIn("startVisibleTemperatureSamplerIfNeeded()", show_popover_body)
        self.assertIn("startBatterySampler()", show_popover_body)

        toggle_popover_body = self._swift_function_body(source, "@objc private func toggleSignalConsole(_ sender: Any?)")
        close_branch = toggle_popover_body.split("showSignalConsolePopover()", 1)[0]
        self.assertIn("stopVisibleTemperatureSampler()", close_branch)
        self.assertIn("startBatterySampler()", close_branch)

        countdown_body = self._swift_function_body(source, "private func startPopoverCountdownTimer()")
        self.assertIn("self.stopVisibleTemperatureSampler()", countdown_body)
        self.assertIn("self.startBatterySampler()", countdown_body)

        power_source_body = self._swift_function_body(source, "private func handlePowerSourceChanged()")
        self.assertIn("sampleBattery()", power_source_body)
        self.assertIn("scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))", power_source_body)
        self.assertIn("configureHardwareSamplersForPowerState()", power_source_body)
        self.assertIn("updateBatteryStatusUI()", power_source_body)
        self.assertIn("private func refreshBatteryStatus()", source)
        self.assertIn("private func updateBatteryStatusUI()", source)

        refresh_battery_body = self._swift_function_body(source, "private func refreshBatteryStatus()")
        self.assertIn("sampleBattery()", refresh_battery_body)
        self.assertIn("updateBatteryStatusUI()", refresh_battery_body)
        self.assertNotIn("rescheduleNextRefreshIfEarlier", refresh_battery_body)

        update_battery_ui_body = self._swift_function_body(source, "private func updateBatteryStatusUI()")
        self.assertIn("rebuildMenu()", update_battery_ui_body)
        self.assertIn("setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)", update_battery_ui_body)
        self.assertIn('setStatusImage(title: "Codex quota")', update_battery_ui_body)
        self.assertIn("refreshSignalPopoverIfNeeded()", update_battery_ui_body)
        self.assertNotIn("rescheduleNextRefreshIfEarlier", update_battery_ui_body)

        start_battery_body = self._swift_function_body(source, "private func startBatterySampler()")
        self.assertIn("self?.refreshBatteryStatus()", start_battery_body)
        self.assertIn("self?.startBatterySampler()", start_battery_body)
        self.assertIn("let interval = batterySampleIntervalForCurrentUI()", start_battery_body)
        self.assertIn("Timer(timeInterval: interval, repeats: false)", start_battery_body)

    def test_battery_signal_appears_in_console_diagnostics_and_tooltip(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "batteryStatusText: String",
            "batteryPercent: Int?",
            "powerSaverText: String",
            "refreshCadenceText: String",
            "batteryStatusText(status: batteryStatus)",
            "batteryPercent: batteryStatus?.percent",
            "powerSaverStatusText()",
            "refreshCadenceStatusText()",
            "batteryStatus: batteryStatus",
            "drawBatteryStatusRow(in: card)",
            "private func drawMenuBarBattery",
            "private func drawMenuBarBatteryModeInfo",
            "private func drawSignalConsoleBatteryIcon",
            "drawMenuBarBatteryTerminal",
            "drawMenuBarBatteryFill",
            "private func batteryMenuBarColor",
            "private func batteryDisplayText",
            "Battery",
            "Power Saver",
            "batteryDoctorCheck(batteryStatus)",
            "Battery state: \\(batteryDiagnosticsText())",
            "Power Saver state: \\(powerSaverStatusText())",
            "parts.append(\"Battery \\(batteryDisplayText(batteryStatus))\")",
        ]:
            self.assertIn(token, source)

        make_status_signature = source.split("private func makeStatusImage(", 1)[1].split(") -> NSImage", 1)[0]
        self.assertIn("batteryStatus: BatteryStatus?", make_status_signature)
        make_status_body = self._swift_function_body(
            source,
            "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage",
        )
        self.assertNotIn("drawMenuBarBattery(status:", make_status_body)
        self.assertNotIn("drawMenuBarBatteryModeInfo", make_status_body)

        codex_detail_body = self._swift_function_body(source, "private func addCodexDetail(_ snapshot: UsageSnapshot)")
        self.assertIn('addDisabled("Battery \\(batteryDisplayText(batteryStatus))")', codex_detail_body)
        self.assertIn("addDisabled(powerSaverStatusText())", codex_detail_body)
        self.assertIn("if hardwareSignalsVisible() {", codex_detail_body)
        self.assertIn("if !hardwareSignalsVisible() {", codex_detail_body)
        self.assertIn("addDisabled(refreshCadenceStatusText())", codex_detail_body)

        battery_row_body = self._swift_function_body(source, "private func drawBatteryStatusRow(in card: NSRect)")
        self.assertIn("let chip = NSRect", battery_row_body)
        self.assertIn("drawSignalConsoleBatteryIcon(percent: model.batteryPercent", battery_row_body)
        self.assertIn("compactSignalConsoleBatteryText()", battery_row_body)
        self.assertIn("model.refreshCadenceText", battery_row_body)
        self.assertIn("model.powerSaverText.contains(\"active\")", battery_row_body)
        self.assertNotIn("let row = NSRect", battery_row_body)
        self.assertIn("private func compactSignalConsoleBatteryText() -> String", source)

    def test_battery_mode_shows_only_usage_and_battery_signals(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private func hardwareSignalsVisible() -> Bool",
            "powerPolicy.hardwareSignalsVisible(powerSaverActive: powerSaverActive())",
            "if hardwareSignalsVisible() {",
            "drawBatteryOnlyMovementNote(in: card)",
            "plugged-in-full",
            "battery-mode",
        ]:
            self.assertIn(token, source)

        make_status_body = self._swift_function_body(
            source,
            "private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage",
        )
        self.assertNotIn("hardwareSignalsVisible()", make_status_body)
        self.assertNotIn("drawMenuBarSSDTemperature", make_status_body)
        self.assertNotIn("drawMenuBarSystemMetricStrip", make_status_body)
        self.assertNotIn("drawMenuBarBattery", make_status_body)

        trend_body = self._swift_function_body(source, "private func drawTrendSection()")
        hardware_branch = trend_body.split("if hardwareSignalsVisible() {", 1)[1].split("} else {", 1)[0]
        battery_branch = trend_body.split("if hardwareSignalsVisible() {", 1)[1].split("} else {", 1)[1]
        self.assertIn("drawSystemMetricMovementRows(in: card)", hardware_branch)
        self.assertIn("drawTemperatureMovementRow(in: card)", hardware_branch)
        self.assertIn("drawBatteryStatusRow(in: card)", hardware_branch)
        self.assertIn("drawBatteryOnlyMovementNote(in: card)", battery_branch)
        self.assertNotIn("drawSystemMetricMovementRows(in: card)", battery_branch)
        self.assertNotIn("drawTemperatureMovementRow(in: card)", battery_branch)

        temp_sampler_body = self._swift_function_body(source, "private func startVisibleTemperatureSamplerIfNeeded()")
        self.assertIn("stopVisibleTemperatureSampler()", temp_sampler_body)
        self.assertIn("guard hardwareSignalsVisible() else", temp_sampler_body)

        tooltip_body = self._swift_function_body(source, "private func menuBarTooltipTitle(title: String, status: ServiceStatus?) -> String")
        tooltip_hardware_branch = tooltip_body.split("if hardwareSignalsVisible() {", 1)[1].split("} else {", 1)[0]
        tooltip_battery_branch = tooltip_body.split("if hardwareSignalsVisible() {", 1)[1].split("} else {", 1)[1]
        self.assertIn('parts.append("SSD \\(temperature)")', tooltip_hardware_branch)
        self.assertIn('parts.append("CPU \\(systemMetricPercentText(metrics.cpuPercent))")', tooltip_hardware_branch)
        self.assertIn("parts.append(powerSaverStatusText())", tooltip_battery_branch)
        self.assertIn("parts.append(refreshCadenceStatusText())", tooltip_battery_branch)

    def test_ssd_temperature_history_samples_every_second_and_is_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct TemperatureSample: Codable", source)
        self.assertIn("let timestamp: Double?", source)
        self.assertIn("timestamp: Double? = nil", source)
        self.assertIn('private let temperatureQueue = DispatchQueue(label: "app.codexgauge.temperature", qos: .utility)', source)
        self.assertIn("private var temperatureTimer: Timer?", source)
        self.assertIn("private var temperatureReadInFlight = false", source)
        self.assertIn("private var temperatureSamples: [TemperatureSample] = []", source)
        self.assertIn("private let temperatureSampleInterval: TimeInterval = 1", source)
        self.assertIn("private let temperatureGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("private let temperatureHistoryRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("private let maxTemperatureSamples = 24 * 60 * 60", source)
        self.assertIn("startTemperatureSampler()", source)
        self.assertIn("sampleTemperature()", source)
        self.assertIn("Timer(timeInterval: temperatureSampleInterval, repeats: true)", source)
        self.assertIn("temperatureQueue.async", source)
        self.assertIn("DispatchQueue.main.async", source)
        self.assertIn("temperatureReadInFlight = true", source)
        self.assertIn("temperatureReadInFlight = false", source)
        self.assertIn("appendTemperatureSample(status)", source)
        self.assertIn("clearTemperatureHistoryAsync()", source)
        self.assertIn("temperatureC: status?.ok == true ? status?.temperatureC : nil", source)
        self.assertIn("ok: status?.ok == true && status?.temperatureC != nil", source)
        self.assertIn("retainedTemperatureSamples", source)
        self.assertIn("readTemperatureSamples", source)

        sample_body = source.split("private func sampleTemperature()", 1)[1].split("private func finishRefresh", 1)[0]
        finish_body = source.split("private func finishRefresh", 1)[1].split("private func refreshModeTitle", 1)[0]
        clear_data_body = source.split("private func performClearLocalData()", 1)[1].split("private func clearTemperatureHistoryAsync", 1)[0]
        clear_temperature_body = source.split("private func clearTemperatureHistoryAsync()", 1)[1].split("private func localDataPathsForClearing", 1)[0]
        setup_doctor_body = source.split("private func runSetupDoctorChecks()", 1)[1].split("private func doctorCheck", 1)[0]
        append_body = source.split("private func appendTemperatureSample", 1)[1].split("private func readTemperatureSamples", 1)[0]
        read_body = source.split("private func readTemperatureSamples", 1)[1].split("private func retainedTemperatureSamples", 1)[0]
        retained_body = source.split("private func retainedTemperatureSamples", 1)[1].split("private func retainedHistorySamples", 1)[0]
        timestamp_body = source.split("private func temperatureSampleTimestamp", 1)[1].split("private func normalizedTemperatureSample", 1)[0]
        normalize_body = source.split("private func normalizedTemperatureSample", 1)[1].split("private func normalizedTemperatureSamples", 1)[0]
        normalize_many_body = source.split("private func normalizedTemperatureSamples", 1)[1].split("private func temperatureGraphSamples", 1)[0]
        diagnostics_body = source.split("private func ssdTemperatureDiagnosticsText()", 1)[1].split("private func safeDiagnosticsText", 1)[0]
        main_update_body = sample_body.split("DispatchQueue.main.async", 1)[1]

        self.assertEqual(source.count("temperatureQueue.async"), 2)
        self.assertEqual(source.count("readSSDTemperature()"), 2)
        self.assertIn("temperatureQueue.async", sample_body)
        self.assertIn("let status = self.readSSDTemperature()", sample_body)
        self.assertNotIn("refreshSignalPopoverIfNeeded()", sample_body)
        self.assertNotIn("writeTemperatureSamples", sample_body)
        self.assertNotIn("writeTemperatureSamples", main_update_body)
        self.assertIn("temperatureSamples = []", clear_data_body)
        self.assertIn("clearTemperatureHistoryAsync()", clear_data_body)
        self.assertIn("temperatureQueue.async", clear_temperature_body)
        self.assertIn("try? FileManager.default.removeItem(atPath: self.temperatureHistoryPath)", clear_temperature_body)
        self.assertIn("temperatureSamples.append(sample)", append_body)
        self.assertIn("temperatureSamples = retainedTemperatureSamples(temperatureSamples)", append_body)
        self.assertIn("timestamp: now.timeIntervalSince1970", append_body)
        self.assertIn("temperatureC: status?.ok == true ? status?.temperatureC : nil", append_body)
        self.assertIn("ok: status?.ok == true && status?.temperatureC != nil", append_body)
        self.assertNotIn("writeTemperatureSamples", append_body)
        self.assertNotIn("isoDate(", append_body)
        self.assertIn("[]", read_body)
        self.assertIn("if let timestamp = sample.timestamp", timestamp_body)
        self.assertIn("isoDate(sample.time)?.timeIntervalSince1970", timestamp_body)
        self.assertIn("sample.timestamp == nil", normalize_body)
        self.assertIn("TemperatureSample(", normalize_body)
        self.assertIn("timestamp: timestamp", normalize_body)
        self.assertIn("samples.map(normalizedTemperatureSample)", normalize_many_body)
        self.assertIn("let cutoff = now.timeIntervalSince1970 - temperatureHistoryRetentionWindow", retained_body)
        self.assertIn("temperatureSampleTimestamp(sample)", retained_body)
        self.assertIn("isoDate(sample.time)", retained_body)
        self.assertIn("temperatureHistoryRetentionWindow", retained_body)
        self.assertIn("suffix(maxTemperatureSamples)", retained_body)
        self.assertNotIn("readSSDTemperature()", finish_body)
        self.assertNotIn("readSSDTemperature()", setup_doctor_body)
        self.assertNotIn("readSSDTemperature()", diagnostics_body)
        self.assertNotIn("persistTemperatureSamplesAsync", source)
        self.assertNotIn("writeTemperatureSamples", source)

    def test_failed_ssd_temperature_reads_back_off_to_avoid_battery_drain(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        for token in [
            "private var temperatureFailureBackoffUntil: Date?",
            "private let temperatureFailureBackoffInterval: TimeInterval = 5 * 60",
            "private func temperatureReadAllowed(now: Date = Date()) -> Bool",
            "private func recordTemperatureReadResult(_ status: SSDTemperatureStatus?, at date: Date = Date())",
            "temperatureFailureBackoffUntil = date.addingTimeInterval(temperatureFailureBackoffInterval)",
            "temperatureFailureBackoffUntil = nil",
        ]:
            self.assertIn(token, source)

        sample_body = self._swift_function_body(source, "private func sampleTemperature()")
        self.assertIn("guard temperatureReadAllowed() else", sample_body)
        self.assertLess(
            sample_body.index("guard temperatureReadAllowed() else"),
            sample_body.index("temperatureReadInFlight = true"),
        )
        self.assertIn("self.recordTemperatureReadResult(status)", sample_body)
        self.assertLess(
            sample_body.index("self.recordTemperatureReadResult(status)"),
            sample_body.index("self.appendTemperatureSample(status)"),
        )

        allowed_body = self._swift_function_body(source, "private func temperatureReadAllowed(now: Date = Date()) -> Bool")
        self.assertIn("guard let temperatureFailureBackoffUntil else", allowed_body)
        self.assertIn("return now >= temperatureFailureBackoffUntil", allowed_body)

        record_body = self._swift_function_body(source, "private func recordTemperatureReadResult(_ status: SSDTemperatureStatus?, at date: Date = Date())")
        self.assertIn("guard status?.ok == true else", record_body)
        self.assertIn("temperatureFailureBackoffUntil = date.addingTimeInterval(temperatureFailureBackoffInterval)", record_body)
        self.assertIn("temperatureFailureBackoffUntil = nil", record_body)

    def test_system_metrics_sample_every_five_seconds_and_are_bounded(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private struct SystemMetricSample: Codable", source)
        self.assertIn("let timestamp: Double?", source)
        self.assertIn("timestamp: Double? = nil", source)
        self.assertIn("private var systemMetricsTimer: Timer?", source)
        self.assertIn("private var systemMetricSamples: [SystemMetricSample] = []", source)
        self.assertIn("private let systemMetricSampleInterval: TimeInterval = 5", source)
        self.assertIn("private let systemMetricGraphWindow: TimeInterval = 10 * 60", source)
        self.assertIn("private let systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60", source)
        self.assertIn("private let maxSystemMetricSamples = 24 * 60 * 60 / 5", source)
        self.assertIn('systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"', source)
        self.assertIn("private lazy var systemMetricsHistoryPath", source)
        self.assertIn("startSystemMetricsSampler()", source)
        self.assertIn("systemMetricsTimer?.invalidate()", source)
        self.assertIn("sampleSystemMetrics()", source)
        self.assertIn("Timer(timeInterval: systemMetricSampleInterval, repeats: true)", source)
        self.assertIn("readSystemMetrics()", source)
        self.assertIn("readCPUUsagePercent()", source)
        self.assertIn("readRAMUsagePercent()", source)
        self.assertIn("host_statistics", source)
        self.assertIn("host_processor_info", source)
        self.assertIn("appendSystemMetricSample", source)
        self.assertIn("retainedSystemMetricSamples", source)
        self.assertIn("systemMetricGraphSamples", source)
        self.assertIn("readSystemMetricSamples", source)
        self.assertIn("private func systemMetricSampleTimestamp", source)
        self.assertIn("private func normalizedSystemMetricSample", source)
        self.assertIn("private func normalizedSystemMetricSamples", source)

        clear_data_body = source.split("private func performClearLocalData()", 1)[1].split("private func clearTemperatureHistoryAsync", 1)[0]
        append_body = source.split("private func appendSystemMetricSample", 1)[1].split("private func readSystemMetricSamples", 1)[0]
        read_body = source.split("private func readSystemMetricSamples", 1)[1].split("private func retainedSystemMetricSamples", 1)[0]
        retained_body = source.split("private func retainedSystemMetricSamples", 1)[1].split("private func retainedTemperatureSamples", 1)[0]
        timestamp_body = source.split("private func systemMetricSampleTimestamp", 1)[1].split("private func normalizedSystemMetricSample", 1)[0]
        normalize_body = source.split("private func normalizedSystemMetricSample", 1)[1].split("private func normalizedSystemMetricSamples", 1)[0]
        normalize_many_body = source.split("private func normalizedSystemMetricSamples", 1)[1].split("private func systemMetricGraphSamples", 1)[0]
        self.assertIn("systemMetricSamples = []", clear_data_body)
        self.assertIn("systemMetricsHistoryPath,", source)
        self.assertIn("systemMetricSamples.append(sample)", append_body)
        self.assertIn("systemMetricSamples = retainedSystemMetricSamples(systemMetricSamples)", append_body)
        self.assertIn("timestamp: now.timeIntervalSince1970", append_body)
        self.assertNotIn("isoDate(", append_body)
        self.assertIn("[]", read_body)
        self.assertIn("if let timestamp = sample.timestamp", timestamp_body)
        self.assertIn("isoDate(sample.time)?.timeIntervalSince1970", timestamp_body)
        self.assertIn("sample.timestamp == nil", normalize_body)
        self.assertIn("SystemMetricSample(", normalize_body)
        self.assertIn("timestamp: timestamp", normalize_body)
        self.assertIn("samples.map(normalizedSystemMetricSample)", normalize_many_body)
        self.assertIn("let cutoff = now.timeIntervalSince1970 - systemMetricRetentionWindow", retained_body)
        self.assertIn("systemMetricSampleTimestamp(sample)", retained_body)
        self.assertIn("systemMetricRetentionWindow", retained_body)
        self.assertIn("suffix(maxSystemMetricSamples)", retained_body)
        self.assertNotIn("persistSystemMetricSamplesAsync", source)
        self.assertNotIn("writeSystemMetricSamples", source)

    def test_ssd_temperature_display_keeps_last_valid_read_briefly(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        self.assertIn("private var lastValidSSDTemperature: SSDTemperatureStatus?", source)
        self.assertIn("private var lastValidSSDTemperatureAt: Date?", source)
        self.assertIn("private let ssdTemperatureDisplayGraceInterval: TimeInterval = 10 * 60", source)
        self.assertIn("private func updateLastValidSSDTemperature", source)
        self.assertIn("private func ssdTemperatureForDisplay(now: Date = Date()) -> SSDTemperatureStatus?", source)
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
            "temperatureHistory: retainedTemperatureHistory",
            "currentTemperatureText(status: ssdTemperatureForDisplay(), samples: retainedTemperatureHistory)",
            "temperatureHistoryText: temperatureHistorySummaryText(retainedTemperatureHistory)",
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
