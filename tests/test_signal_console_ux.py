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
            "doctorChecks",
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
        make_status_body = swift_function_body(source, "private func makeStatusImage(")
        countdown_body = swift_function_body(source, "private func drawMenuBarRefreshCountdown(")
        usage_row_body = swift_function_body(source, "private func drawMenuBarUsagePercentRow(")

        for token in [
            "statusItemWidth: CGFloat = 104",
            "statusImageSize = NSSize(width: 98, height: 22)",
            "menuBarUsagePercentRect = NSRect(x: 6, y: 3, width: 46, height: 16)",
            "menuBarRefreshCountdownRect = NSRect(x: 58, y: 2.2, width: 34, height: 17.6)",
            "for x in [54] as [CGFloat]",
            "drawMenuBarMinimalMorandiPill",
            "drawMenuBarUsagePercentBars",
            "drawMenuBarCountdownPill",
            "morandiMenuBarSage",
            "morandiMenuBarMist",
            "morandiMenuBarClay",
            "morandiMenuBarTaupe",
        ]:
            self.assertIn(token, source)
        self.assertIn("drawPlanBGauge(", make_status_body)
        self.assertIn("drawMenuBarCountdownPill(text: fiveHourText", countdown_body)
        self.assertIn("drawMenuBarCountdownPill(text: sevenDayText", countdown_body)
        self.assertNotIn("percentText", usage_row_body)
        self.assertNotIn("drawMenuBarHardwareSignals", source)
        self.assertNotIn("drawMenuBarSSDTemperature", source)
        self.assertNotIn("drawMenuBarSystemMetricStrip", source)
        self.assertNotIn("drawMenuBarBattery", source)
        self.assertNotIn("drawResetMoodFace", source)
        self.assertNotIn("drawMoodLane", source)

    def test_reset_countdowns_keep_minutes_without_a_face_marker(self):
        source = swift_source()
        compact_body = swift_function_body(source, "private func compactResetCountdown(")
        lane_body = swift_function_body(source, "private func drawResetCountdownLane(")

        self.assertIn("compactResetCountdown(epoch, includeMinutes: true, includeDays: false)", source)
        self.assertIn("compactResetCountdown(epoch, includeMinutes: false, includeDays: true)", source)
        self.assertIn('return "\\(minutes)m"', compact_body)
        self.assertIn('return "\\(hours)h\\(remainingMinutes)m"', compact_body)
        self.assertIn('return "\\(days)d\\(remainingHours)h"', compact_body)
        self.assertIn("drawRoundedRect", lane_body)
        self.assertIn("fillWidth", lane_body)
        self.assertIn("resetLaneGradient", lane_body)
        self.assertNotIn("drawCircle", lane_body)
        self.assertNotIn("face", lane_body.lower())

    def test_signal_console_shows_codex_only_diagnostics_and_no_device_telemetry(self):
        source = swift_source()

        for token in [
            "Codex-only signal",
            "No device telemetry sampled",
            'title: "Codex app found"',
            'title: "Helper works"',
            'title: "Live data available"',
            'title: "Session storage"',
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
        ]:
            self.assertNotIn(blocked, source)

    def test_signal_console_preview_cases_cover_current_public_states(self):
        source = swift_source()
        preview_body = source.split("private func signalConsolePreviewCases()", 1)[1].split(
            "private func signalConsolePreviewModel", 1
        )[0]

        for slug in ['"live"', '"codex-closed"', '"last-live"', '"low-quota"', '"reset-soon"']:
            self.assertIn(slug, preview_body)
        self.assertIn('fiveHourResetText: "4h59m"', preview_body)
        self.assertIn('sevenDayResetText: "6d23h"', preview_body)
        self.assertIn('fiveHourResetText: "59m"', preview_body)
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
            self.assertIn("pixelWidth: 1120", result.stdout)
            self.assertIn("pixelHeight: 1120", result.stdout)


if __name__ == "__main__":
    unittest.main()
