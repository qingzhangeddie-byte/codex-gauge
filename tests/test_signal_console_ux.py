import pathlib
import subprocess
import unittest


def swift_source() -> str:
    return pathlib.Path("native/CodexGauge.swift").read_text()


def swift_function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"Could not parse function body for {signature}")


class SignalConsoleUXTests(unittest.TestCase):
    def test_signal_console_model_is_codex_only(self):
        source = swift_source()
        model_block = source.split("private struct SignalConsoleModel", 1)[1].split(
            "private final class SignalConsolePanelView", 1
        )[0]

        for token in [
            "fiveHourLeft",
            "sevenDayLeft",
            "fiveHourResetText",
            "sevenDayResetText",
            "nextRefreshText",
        ]:
            self.assertIn(token, model_block)
        for blocked in [
            "battery",
            "Battery",
            "ssdTemperature",
            "temperatureHistory",
            "systemMetric",
            "CPU",
            "RAM",
        ]:
            self.assertNotIn(blocked, model_block)

    def test_menu_bar_uses_minimal_morandi_usage_and_countdown_design(self):
        source = swift_source()
        draw_status_body = swift_function_body(source, "private func drawStatusItemView(")
        countdown_body = swift_function_body(source, "private func drawMenuBarRefreshCountdown(")
        usage_row_body = swift_function_body(source, "private func drawMenuBarUsagePercentRow(")

        for token in [
            "statusItemWidth: CGFloat = 94",
            "private final class CodexGaugeStatusItemView",
            "button.addSubview(statusItemView)",
            "statusItemView.autoresizingMask = [.width, .height]",
            "override func viewDidChangeEffectiveAppearance()",
            "menuBarUsagePercentRect = NSRect(x: 2, y: 3, width: 54, height: 16)",
            "menuBarHorizontalRailRect = NSRect(x: 46, y: 3, width: 22, height: 16)",
            "menuBarRefreshCountdownRect = NSRect(x: 69, y: 2, width: 24, height: 18)",
            "quotaRailSize = NSSize(width: 22, height: 5)",
            "drawMenuBarUsagePercentRow(window: \"5h\", quotaLeft: fiveHourLeft, y: 13.0",
            "drawMenuBarUsagePercentRow(window: \"7d\", quotaLeft: sevenDayLeft, y: 4.0",
            "NSFont.monospacedDigitSystemFont(ofSize: 8.0, weight: .semibold)",
            "NSFont.monospacedDigitSystemFont(ofSize: 7.2, weight: .medium)",
            "drawMenuBarUsagePercentBars",
            "drawMenuBarHorizontalQuotaBar",
            "systemMonitorMenuBarTextColor",
            "systemMonitorMenuBarBlue",
            "let cornerRadius = min(0.9, rect.height / 4.0)",
            "let fillInset: CGFloat = 1.0",
            "let innerTrackRect = statusPixelAlignedRect(trackRect.insetBy(dx: fillInset, dy: fillInset))",
            "let minimumVisibleFillWidth: CGFloat = 2.4",
            "max(minimumVisibleFillWidth, innerTrackRect.width * fraction)",
            "track.addClip()",
            "fillRect.fill()",
            "statusItemView.window?.effectiveAppearance ?? statusItemView.effectiveAppearance",
            "NSColor(calibratedWhite: 0.97, alpha: 0.96)",
            "Sampled from the adjacent iStat Menus CPU fill block (#8696B9).",
            "NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)",
            "Sampled from the adjacent iStat Menus CPU meter well around the blue fill.",
            "NSColor(deviceWhite: 0.08, alpha: 0.95)",
            "drawMenuBarCountdownText",
            "compactMenuBarPercentText",
            "morandiMenuBarSage",
            "morandiMenuBarMist",
            "morandiMenuBarClay",
            "morandiMenuBarTaupe",
        ]:
            self.assertIn(token, source)
        self.assertIn("drawPlanBGauge(", draw_status_body)
        self.assertIn("drawMenuBarCountdownText(text: fiveHourText", countdown_body)
        self.assertIn("drawMenuBarCountdownText(text: sevenDayText", countdown_body)
        self.assertIn("compactMenuBarPercentText(value)", usage_row_body)
        self.assertIn("percentText as NSString", usage_row_body)
        self.assertNotIn("let cornerRadius = rect.height / 2", source)
        self.assertNotIn("systemMonitorMenuBarMeterOutlineColor().setStroke()", source)
        self.assertNotIn("NSColor(calibratedWhite: 1.0, alpha: 0.12)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.07)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.07, alpha: 0.96)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.16)", source)
        self.assertNotIn("NSColor(calibratedWhite: 0.08, alpha: 0.12)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.525, green: 0.588, blue: 0.725, alpha: 1.0)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.18, green: 0.56, blue: 0.96, alpha: 0.92)", source)
        self.assertNotIn("NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.75, alpha: 0.98)", source)
        self.assertNotIn("drawMenuBarVerticalQuotaMeter", source)
        self.assertNotIn("drawMenuBarMinimalMorandiPill", source)
        self.assertNotIn("morandiMenuBarShellTop", source)
        self.assertNotIn("morandiMenuBarShellBottom", source)
        self.assertNotIn("drawMenuBarHardwareSignals", source)
        self.assertNotIn("drawMenuBarSSDTemperature", source)
        self.assertNotIn("drawMenuBarSystemMetricStrip", source)
        self.assertNotIn("drawMenuBarBattery", source)
        self.assertNotIn("drawResetMoodFace", source)
        self.assertNotIn("drawMenuBarChrome", source)
        self.assertNotIn("drawMenuBarMorandiDivider", source)
        self.assertNotIn("drawSourceIndicator", source)
        self.assertNotIn("drawStatusStateBadge", source)
        self.assertNotIn("drawResetMinimalMarker", source)
        self.assertNotIn("drawMoodLane", source)

    def test_reset_countdowns_keep_minutes_without_a_face_marker(self):
        source = swift_source()
        compact_body = swift_function_body(source, "private func compactResetCountdown(")

        self.assertIn("compactResetCountdown(epoch, includeMinutes: true, includeDays: false)", source)
        self.assertIn("compactResetCountdown(epoch, includeMinutes: false, includeDays: true)", source)
        self.assertIn('return "\\(minutes)m"', compact_body)
        self.assertIn('return "\\(hours)h\\(remainingMinutes)m"', compact_body)
        self.assertIn('return "\\(days)d\\(remainingHours)h"', compact_body)
        self.assertIn('drawText("resets \\(resetText)"', source)
        self.assertNotIn("drawResetCountdownLane", source)
        self.assertNotIn("face", compact_body.lower())

    def test_signal_console_is_compact_live_only_and_accessible(self):
        source = swift_source()

        for token in [
            "signalPopoverSize = NSSize(width: 380, height: 272)",
            'setAccessibilityLabel("Codex Gauge quota")',
            'symbol: "arrow.clockwise"',
            'symbol: "gearshape"',
            'symbol: "power"',
            'title: "ChatGPT app found"',
            'title: "Helper works"',
            'title: "Live data available"',
            'title: "Launch at login"',
            'title: "Notifications permission"',
            "safeDiagnosticsText",
            "Excludes: browser cookies",
        ]:
            self.assertIn(token, source)
        for blocked in [
            "SSD temp",
            "Battery mode",
            "Power Saver",
            "CPU/RAM",
            "readCPUUsagePercent",
            "readRAMUsagePercent",
            '"Clear legacy"',
            '"Usage summary"',
            '"Movement"',
        ]:
            self.assertNotIn(blocked, source)

    def test_signal_console_preview_cases_cover_current_public_states(self):
        source = swift_source()
        preview_body = source.split("private func signalConsolePreviewCases()", 1)[1].split(
            "private func signalConsolePreviewModel", 1
        )[0]

        for slug in ['"live"', '"codex-closed"', '"low-quota"', '"reset-soon"']:
            self.assertIn(slug, preview_body)
        self.assertIn('fiveHourResetText: "4h59m"', preview_body)
        self.assertIn('sevenDayResetText: "6d23h"', preview_body)
        self.assertIn('fiveHourResetText: "59m"', preview_body)
        self.assertIn('planName: unavailable ? "Live only" : "Codex Pro"', source)
        self.assertNotIn('"last-live"', preview_body)
        self.assertNotIn("battery-mode", preview_body)
        self.assertNotIn("plugged-in-full", preview_body)

    def test_native_app_can_render_real_signal_console_fixtures(self):
        script = pathlib.Path("script/render_signal_console_fixtures.sh")
        self.assertTrue(script.exists())
        self.assertIn("Contents/MacOS/CodexGauge", script.read_text())
        self.assertNotIn("CodexGauge-bin", script.read_text())

        fixture_dir = pathlib.Path("docs/design/app-rendered-signal-console")
        expected = [
            "blue-ceramic-live.png",
            "blue-ceramic-reset-soon.png",
            "signal-dark-live.png",
            "signal-dark-reset-soon.png",
            "mono-graphite-live.png",
            "mono-graphite-reset-soon.png",
        ]
        for filename in expected:
            fixture = fixture_dir / filename
            self.assertTrue(fixture.exists(), filename)
            result = subprocess.run(
                ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(fixture)],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            )
            self.assertIn("pixelWidth: 760", result.stdout)
            self.assertIn("pixelHeight: 544", result.stdout)


if __name__ == "__main__":
    unittest.main()
