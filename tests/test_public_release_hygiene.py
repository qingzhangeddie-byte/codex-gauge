import pathlib
import subprocess
import unittest


class PublicReleaseHygieneTests(unittest.TestCase):
    def test_gitignore_excludes_private_runtime_artifacts(self):
        gitignore = pathlib.Path(".gitignore").read_text()

        for pattern in [
            ".venv/",
            "*.log",
            "*.app",
            ".env",
            "native/build/",
            "native/dist/",
            "docs/marketing/",
        ]:
            self.assertIn(pattern, gitignore)
        self.assertNotIn("menubar/", gitignore)

    def test_public_package_does_not_ship_legacy_python_menubar_app(self):
        self.assertFalse(pathlib.Path("menubar").exists())
        self.assertFalse(list(pathlib.Path("docs").glob("screenshot-*.png")))

    def test_public_package_does_not_ship_legacy_cli_surface(self):
        install = pathlib.Path("install.sh").read_text()
        public_docs = "\n".join(
            pathlib.Path(path).read_text(encoding="utf-8")
            for path in ["README.md", "README.zh-CN.md", "docs/PRIVACY.md", "docs/PUBLISHING.md"]
        )

        self.assertFalse(pathlib.Path("usage.py").exists())
        self.assertFalse(pathlib.Path("requirements.txt").exists())
        for text in [install, public_docs]:
            self.assertNotIn("usage.py", text)
            self.assertNotIn("requirements.txt", text)
            self.assertNotIn("browser-cookie3", text)
            self.assertNotIn("<your-fork-url>", text)
            self.assertNotIn("ai-limit", text)
            self.assertNotIn(".claude", text)
            self.assertNotIn("--allow-browser-cookies", text)
            self.assertNotIn("--allow-codex-auth", text)

    def test_ci_runs_unit_tests(self):
        workflow = pathlib.Path(".github/workflows/test.yml").read_text()

        self.assertIn("python -m unittest discover -s tests", workflow)
        self.assertIn("macos-", workflow)
        self.assertIn("python-version: [\"3.9\", \"3.11\"]", workflow)
        self.assertIn("./script/build_and_run.sh --build-only", workflow)

    def test_publishing_docs_cover_privacy_signing_and_homebrew(self):
        docs = pathlib.Path("docs/PUBLISHING.md").read_text()

        self.assertIn("Privacy", docs)
        self.assertIn("Codex Gauge", docs)
        self.assertIn("codesign", docs)
        self.assertIn("notarization", docs)
        self.assertIn("Homebrew", docs)
        self.assertIn("do not publish logs", docs)
        self.assertIn("clean orphan history", docs)
        self.assertIn("git clone https://github.com/qingzhangeddie-byte/codex-gauge.git", docs)

    def test_public_release_docs_exist(self):
        changelog = pathlib.Path("CHANGELOG.md").read_text(encoding="utf-8")
        security = pathlib.Path("SECURITY.md").read_text(encoding="utf-8")
        notice = pathlib.Path("NOTICE").read_text(encoding="utf-8")

        self.assertIn("v0.4.1", changelog)
        self.assertIn("v0.4.0", changelog)
        self.assertIn("Codex Gauge", changelog)
        self.assertIn("Security Policy", security)
        self.assertIn("does not read browser cookies", security)
        self.assertIn("does not read `~/.codex/auth.json`", security)
        self.assertIn("Codex Gauge contributors", notice)
        self.assertIn("original upstream work", notice)
        self.assertIn("Apache License, Version 2.0", notice)
        self.assertIn("v0.5.0", changelog)
        self.assertIn("v0.6.0", changelog)
        self.assertIn("v0.7.0", changelog)
        self.assertIn("v0.8.0", changelog)
        self.assertIn("v0.9.0", changelog)
        self.assertIn("v0.9.1", changelog)
        self.assertIn("v0.9.2", changelog)

    def test_release_check_script_covers_public_release_gates(self):
        script_path = pathlib.Path("script/release_check.sh")
        script = script_path.read_text()

        self.assertTrue(script_path.exists())
        self.assertIn("python3 -m unittest discover -s tests -v", script)
        self.assertIn("bash -n script/package_release.sh", script)
        self.assertIn("bash -n script/soak_check.sh", script)
        self.assertIn("./script/build_and_run.sh --build-only", script)
        self.assertIn("ditto --norsrc --noextattr", script)
        self.assertIn("codesign --verify --deep --strict", script)
        self.assertIn("CFBundleShortVersionString", script)
        self.assertIn("CodexGaugeReleaseURL", script)
        self.assertNotIn('Contents/Resources/ssd_temperature', script)
        self.assertIn("git ls-files", script)
        self.assertIn("git grep -n -I -E", script)
        self.assertNotIn("grep -R -I -n -E", script)
        self.assertIn("pixelWidth: 1280", script)
        self.assertIn("swift script/generate_theme_state_previews.swift", script)
        self.assertIn("swift script/generate_public_assets.swift", script)
        self.assertIn("script/render_signal_console_fixtures.sh", script)
        self.assertIn("Codex Gauge release check passed.", script)

    def test_package_release_script_builds_zip_checksum_and_installer(self):
        script_path = pathlib.Path("script/package_release.sh")
        self.assertTrue(script_path.exists())
        script = script_path.read_text()

        self.assertIn("CodexGauge-$APP_VERSION.zip", script)
        self.assertIn("COPYFILE_DISABLE=1", script)
        self.assertIn("ditto --norsrc --noextattr -c -k --keepParent", script)
        self.assertIn("shasum -a 256", script)
        self.assertIn("Install Codex Gauge.command", script)
        self.assertIn("README-INSTALL.txt", script)
        self.assertIn("./script/build_and_run.sh --build-only", script)
        self.assertIn("AiLimitStatus.app", script)
        self.assertIn("app.codexgauge.menubar.plist", script)
        self.assertIn('rm -f "$AGENT_PLIST"', script)
        self.assertIn("launch_app_binary", script)
        self.assertNotIn("launchctl bootstrap", script)
        self.assertIn("not notarized", script)
        self.assertNotIn("docs/marketing", script)
        self.assertNotIn("CodexGauge-runtime.log", script)

    def test_soak_check_script_samples_status_over_time(self):
        script_path = pathlib.Path("script/soak_check.sh")
        self.assertTrue(script_path.exists())
        script = script_path.read_text()

        self.assertIn("--iterations", script)
        self.assertIn("--interval", script)
        self.assertIn("CodexGauge-soak", script)
        self.assertIn("jsonl", script)
        self.assertIn("source_counts", script)
        self.assertIn("unavailable_count", script)
        self.assertIn("--status-json", script)
        self.assertIn("native/codex_status.py", script)
        self.assertNotIn("--battery-mode", script)
        self.assertNotIn("CodexGauge-battery-soak", script)
        self.assertNotIn("ssd_parse_failures", script)
        self.assertNotIn("pmset -g batt", script)
        self.assertNotIn("browser-cookie", script)

    def test_public_visual_assets_exist_and_are_bounded(self):
        hero = pathlib.Path("docs/assets/codex-gauge-github-hero.png")
        live = pathlib.Path("docs/assets/codex-gauge-menubar-live.png")
        console = pathlib.Path("docs/assets/codex-gauge-signal-console.png")
        social = pathlib.Path("docs/assets/codex-gauge-social-preview.png")

        self.assertTrue(hero.exists())
        self.assertTrue(live.exists())
        self.assertTrue(console.exists())
        self.assertTrue(social.exists())
        self.assertLess(hero.stat().st_size, 3_000_000)
        self.assertLess(live.stat().st_size, 2_000_000)
        self.assertLess(console.stat().st_size, 2_000_000)
        self.assertLess(social.stat().st_size, 3_000_000)

        result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(social)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("pixelWidth: 1280", result.stdout)
        self.assertIn("pixelHeight: 640", result.stdout)

        hero_result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(hero)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("pixelWidth: 1280", hero_result.stdout)
        self.assertIn("pixelHeight: 640", hero_result.stdout)

        console_result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(console)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("pixelWidth: 1280", console_result.stdout)
        self.assertIn("pixelHeight: 640", console_result.stdout)

        live_result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(live)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("pixelWidth: 430", live_result.stdout)
        self.assertIn("pixelHeight: 96", live_result.stdout)

    def test_public_asset_generator_draws_menu_bar_strip(self):
        script = pathlib.Path("script/generate_public_assets.swift").read_text()

        self.assertIn("heroOutputPath", script)
        self.assertIn("docs/assets/codex-gauge-github-hero.png", script)
        self.assertIn("writeMenuBarPNG(menuBarPath)", script)
        self.assertIn("let strip = NSRect(x: 64, y: 20, width: 252, height: 56)", script)
        self.assertIn("drawMenuBarHorizontalQuotaBar(value:", script)
        self.assertIn("systemMonitorBlue", script)
        self.assertIn("xRadius: 1.0", script)
        self.assertIn("shell.addClip()", script)
        self.assertIn("fillRect.fill()", script)
        self.assertIn("max(4.4, rect.width * fraction)", script)
        self.assertIn("NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)", script)
        self.assertNotIn("NSColor(calibratedRed: 0.525, green: 0.588, blue: 0.725, alpha: 1.0)", script)
        self.assertNotIn("NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.75, alpha: 0.98)", script)
        self.assertIn("NSColor(calibratedWhite: 0.08, alpha: 0.07)", script)
        self.assertNotIn("NSColor(calibratedWhite: 0.07, alpha: 0.96)", script)
        self.assertNotIn("let innerRect = rect.insetBy(dx: 2.0, dy: 2.0)", script)
        self.assertNotIn("xRadius: rect.height / 2", script)
        self.assertNotIn("drawMenuBarVerticalQuotaMeter(value:", script)
        self.assertIn("drawMenuBarRefreshCountdown", script)
        self.assertIn("drawMenuBarCountdownText", script)
        self.assertNotIn("NSBezierPath(roundedRect: strip", script)
        self.assertNotIn("drawMenuBarMorandiDivider", script)
        self.assertNotIn("divider quota countdown", script)
        self.assertNotIn("min(rect.maxX - 5, fillRect.maxX - 5)", script)
        self.assertIn("Codex quota where you actually look", script)
        self.assertIn("4h59m", script)
        self.assertIn("6d23h", script)
        self.assertNotIn("appendArc(withCenter", script)
        self.assertIn("Static public screenshot with sample quota values", script)
        self.assertNotIn("4h37m", script)
        self.assertNotIn("6d8h", script)
        self.assertNotIn('menuBarText("45°"', script)
        self.assertNotIn('menuBarText("C43"', script)
        self.assertNotIn("let battery = NSBezierPath", script)
        self.assertNotIn("drawMenuBarCircuitAccent", script)

    def test_theme_state_visual_fixture_generator_covers_all_states(self):
        script = pathlib.Path("script/generate_theme_state_previews.swift")
        fixture = pathlib.Path("docs/design/codex-gauge-theme-state-fixtures.png")

        self.assertTrue(script.exists())
        self.assertTrue(fixture.exists())
        script_text = script.read_text()
        for phrase in [
            "Blue Ceramic",
            "Signal Dark",
            "Mono Graphite",
            "Live",
            "Codex closed",
            "Live only",
            "Low quota",
            "Reset soon",
            "docs/design/codex-gauge-theme-state-fixtures.png",
        ]:
            self.assertIn(phrase, script_text)
        self.assertLess(fixture.stat().st_size, 3_000_000)

        result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(fixture)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertIn("pixelWidth: 1280", result.stdout)
        self.assertIn("pixelHeight: 1220", result.stdout)

    def test_actual_app_rendered_signal_console_fixtures_exist(self):
        script = pathlib.Path("script/render_signal_console_fixtures.sh")
        fixture_dir = pathlib.Path("docs/design/app-rendered-signal-console")
        expected = [
            "blue-ceramic-live.png",
            "blue-ceramic-codex-closed.png",
            "blue-ceramic-last-live.png",
            "blue-ceramic-low-quota.png",
            "blue-ceramic-reset-soon.png",
            "signal-dark-live.png",
            "signal-dark-codex-closed.png",
            "signal-dark-last-live.png",
            "signal-dark-low-quota.png",
            "signal-dark-reset-soon.png",
            "mono-graphite-live.png",
            "mono-graphite-codex-closed.png",
            "mono-graphite-last-live.png",
            "mono-graphite-low-quota.png",
            "mono-graphite-reset-soon.png",
        ]

        self.assertTrue(script.exists())
        self.assertTrue(fixture_dir.exists())
        script_text = script.read_text()
        self.assertIn("--render-signal-console-fixtures", script_text)
        self.assertIn("native/dist/CodexGauge.app/Contents/MacOS/CodexGauge", script_text)
        self.assertNotIn("CodexGauge-bin", script_text)
        for filename in expected:
            fixture = fixture_dir / filename
            self.assertTrue(fixture.exists(), filename)
            self.assertLess(fixture.stat().st_size, 2_000_000)
            result = subprocess.run(
                ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(fixture)],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            )
            self.assertIn("pixelWidth: 1120", result.stdout)
            self.assertIn("pixelHeight: 1120", result.stdout)
        self.assertFalse(list(fixture_dir.glob("*battery-mode.png")))
        self.assertFalse(list(fixture_dir.glob("*plugged-in-full.png")))
        self.assertIn("blue-ceramic", pathlib.Path("native/CodexGauge.swift").read_text())

    def test_public_visual_assets_are_generated_from_real_app_render(self):
        script = pathlib.Path("script/generate_public_assets.swift")

        self.assertTrue(script.exists())
        script_text = script.read_text()
        self.assertIn("docs/design/app-rendered-signal-console/blue-ceramic-live.png", script_text)
        self.assertIn("docs/design/app-rendered-signal-console/signal-dark-live.png", script_text)
        self.assertIn("docs/assets/codex-gauge-github-hero.png", script_text)
        self.assertIn("docs/assets/codex-gauge-signal-console.png", script_text)
        self.assertIn("docs/assets/codex-gauge-social-preview.png", script_text)
        self.assertIn("actual app-rendered Signal Console", script_text)
        self.assertIn("sample quota values", script_text)
        native_source = pathlib.Path("native/CodexGauge.swift").read_text()
        self.assertIn('fiveHourResetText: "4h59m"', native_source)
        self.assertIn('sevenDayResetText: "6d23h"', native_source)
        self.assertNotIn('fiveHourResetText: "4h37m"', native_source)
        self.assertNotIn('sevenDayResetText: "5d22h"', native_source)

    def test_build_script_installs_public_app_name_and_removes_legacy_app(self):
        script = pathlib.Path("script/build_and_run.sh").read_text()
        install = pathlib.Path("install.sh").read_text()

        self.assertIn('APP_NAME="CodexGauge"', script)
        self.assertIn('CFBundleName</key>', script)
        self.assertIn("Codex Gauge", script)
        self.assertIn("CodexGaugeUsagePath", script)
        self.assertIn('LEGACY_APP_NAME="AiLimitStatus"', script)
        self.assertIn('LEGACY_APP_DEST="/Applications/AiLimitStatus.app"', install)
        self.assertIn('APP_DEST="/Applications/CodexGauge.app"', install)
        self.assertNotIn("CLI_BIN", install)
        self.assertNotIn("venv", install.lower())

    def test_publishing_docs_include_github_web_checklist_and_release_tag(self):
        docs = pathlib.Path("docs/PUBLISHING.md").read_text()

        for phrase in [
            "git@github.com:qingzhangeddie-byte/codex-gauge.git",
            "git push -u origin main --tags",
            "v0.9.2",
            "repository social preview",
            "docs/assets/codex-gauge-social-preview.png",
            "private vulnerability reporting",
            "macos",
            "usage-monitor",
        ]:
            self.assertIn(phrase, docs)


if __name__ == "__main__":
    unittest.main()
