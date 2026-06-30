import pathlib
import re
import unittest


class CodexOnlyScopeTests(unittest.TestCase):
    def test_native_app_does_not_ship_hardware_signal_features(self):
        source = pathlib.Path("native/CodexGauge.swift").read_text()

        forbidden_tokens = [
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
            "readCPUUsagePercent",
            "readRAMUsagePercent",
            "drawMenuBarHardwareSignals",
        ]
        for token in forbidden_tokens:
            self.assertNotIn(token, source)

    def test_native_package_contains_only_codex_status_helper(self):
        build_script = pathlib.Path("script/build_and_run.sh").read_text()
        replace_script = pathlib.Path("script/replace_installed_app.sh").read_text()

        self.assertFalse(pathlib.Path("native/ssd_temperature.m").exists())
        self.assertNotIn("ssd_temperature", build_script)
        self.assertNotIn("IOReport", build_script)
        self.assertNotIn("-framework IOKit", build_script)
        self.assertNotIn("CodexGaugePowerPolicy.swift", build_script)
        self.assertNotIn("ssd_temperature", replace_script)

    def test_public_docs_describe_codex_usage_only(self):
        public_docs = [
            "README.md",
            "README.zh-CN.md",
            "docs/PRIVACY.md",
            "docs/PUBLISHING.md",
        ]
        forbidden = re.compile(r"SSD|CPU/RAM|CPU and RAM|battery|Battery|Power Saver|hardware", re.IGNORECASE)
        for path in public_docs:
            text = pathlib.Path(path).read_text()
            self.assertIsNone(forbidden.search(text), path)

    def test_public_visual_generators_are_codex_only(self):
        public_assets = pathlib.Path("script/generate_public_assets.swift").read_text()
        theme_previews = pathlib.Path("script/generate_theme_state_previews.swift").read_text()

        for token in ["SSD", "CPU", "RAM", "battery", "Battery", "hardware", "42°", "C36", "R62"]:
            self.assertNotIn(token, public_assets)
            self.assertNotIn(token, theme_previews)
