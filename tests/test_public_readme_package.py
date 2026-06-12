import pathlib
import unittest


class PublicReadmePackageTests(unittest.TestCase):
    def test_readme_brands_project_as_codex_gauge(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        self.assertTrue(readme.startswith("# Codex Gauge\n"))
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml/badge.svg", readme)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases/latest", readme)
        self.assertIn("docs/assets/codex-gauge-menubar-live.png", readme)
        self.assertIn("A simple, safe macOS menu bar app to check Codex usage", readme)
        self.assertIn("Unofficial", readme)
        self.assertIn("docs/assets/codex-gauge-menu.svg", readme)
        self.assertLess(
            readme.index("docs/assets/codex-gauge-menubar-live.png"),
            readme.index("A simple, safe macOS menu bar app"),
        )

    def test_readme_uses_real_public_repo_url_badges_and_faq(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for phrase in [
            "https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml/badge.svg",
            "https://github.com/qingzhangeddie-byte/codex-gauge/releases/latest",
            "git clone https://github.com/qingzhangeddie-byte/codex-gauge.git",
            "check Codex usage",
            "Codex rate limit tracker",
            "Codex 5-hour limit",
            "Codex 7-day quota",
            "OpenAI Codex usage monitor",
            "Codex quota tracker",
            "macOS Codex menu bar app",
            "查看 Codex 使用量",
            "Codex 额度监控",
            "Codex 菜单栏工具",
            "## FAQ",
            "Does Codex Gauge read browser cookies?",
            "Does this trigger the 5-hour window?",
        ]:
            self.assertIn(phrase, readme)

    def test_readme_has_line_by_line_chinese_explanation(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for phrase in [
            "Codex Gauge 是一个**非官方** macOS 菜单栏工具",
            "它可以直接显示 Codex 5 小时剩余额度和 Codex 7 天剩余额度",
            "菜单栏紧凑显示 Codex 5 小时额度和 7 天额度",
            "下拉菜单显示额度重置时间和上次刷新时间",
            "紧凑菜单栏仪表使用 mood-lane 设计",
            "四个信号分别是 5 小时额度剩余",
            "很多使用量工具是大而全的 dashboard",
            "## SEO Keywords",
        ]:
            self.assertIn(phrase, readme)

    def test_readme_explains_why_it_is_different(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for phrase in [
            "Why Codex Gauge is different",
            "No browser cookies in the menu bar app",
            "No `~/.codex/auth.json` reads in the menu bar app",
            "Self-contained app bundle",
            "Adaptive refresh",
            "Reset timing",
            "About a minute",
            "LaunchAgent",
        ]:
            self.assertIn(phrase, readme)

    def test_readmes_explain_uninstall_and_notice(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")
        zh_readme = pathlib.Path("README.zh-CN.md").read_text(encoding="utf-8")

        for phrase in [
            "## Uninstall",
            "launchctl bootout",
            "app.codexgauge.menubar",
            "Application Support/CodexGauge",
            "[NOTICE](NOTICE)",
        ]:
            self.assertIn(phrase, readme)

        for phrase in [
            "## 卸载",
            "launchctl bootout",
            "app.codexgauge.menubar",
            "Application Support/CodexGauge",
            "[NOTICE](NOTICE)",
        ]:
            self.assertIn(phrase, zh_readme)

    def test_readme_avoids_personal_promo_and_old_project_name(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        self.assertNotIn("Other projects by the author", readme)
        self.assertNotIn("support the author", readme)
        self.assertNotIn("Star would be appreciated", readme)
        self.assertNotIn("Claude", readme)

    def test_public_docs_keep_codex_gauge_positioning(self):
        for path in ["README.md", "README.zh-CN.md", "docs/PRIVACY.md"]:
            text = pathlib.Path(path).read_text(encoding="utf-8")

            self.assertNotIn("Claude", text)
            self.assertNotIn("claude", text)

    def test_readmes_explain_mood_lane_menu_bar_signal(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")
        zh_readme = pathlib.Path("README.zh-CN.md").read_text(encoding="utf-8")

        for phrase in [
            "Four-signal menu bar",
            "docs/design/codex-gauge-four-bar-mockup.svg",
            "5-hour quota left",
            "5-hour reset countdown",
            "7-day quota left",
            "7-day reset countdown",
            "mood-lane design",
            "red through coral and orange into warm yellow",
            "tiny vector face",
            "slides right",
            "frown to smile",
            "docs/assets/codex-gauge-color-states.svg",
            "healthy, watch, and critical states",
            "simulated",
        ]:
            self.assertIn(phrase, readme)

        for phrase in [
            "四条菜单栏信号",
            "docs/design/codex-gauge-four-bar-mockup.svg",
            "5 小时额度剩余",
            "5 小时重置倒计时",
            "7 天额度剩余",
            "7 天重置倒计时",
            "mood-lane",
            "红色过渡到珊瑚色、橙色",
            "温暖黄色",
            "矢量脸",
            "向右移动",
            "从皱眉过渡到微笑",
            "docs/assets/codex-gauge-color-states.svg",
            "模拟示例",
        ]:
            self.assertIn(phrase, zh_readme)

    def test_public_readmes_do_not_include_private_local_identity(self):
        for path in ["README.md", "README.zh-CN.md"]:
            readme = pathlib.Path(path).read_text(encoding="utf-8")

            self.assertNotIn("/Users/", readme)
            self.assertNotIn("bustawind", readme.lower())

    def test_zh_readme_uses_public_codex_gauge_name(self):
        readme = pathlib.Path("README.zh-CN.md").read_text(encoding="utf-8")

        self.assertTrue(readme.startswith("# Codex Gauge\n"))
        self.assertIn("简单、安全的 Codex 菜单栏额度仪表", readme)
        self.assertIn("git clone https://github.com/qingzhangeddie-byte/codex-gauge.git", readme)
        for phrase in [
            "## FAQ",
            "### 如何查看 Codex 还剩多少额度？",
            "### 这是 Codex rate limit tracker 吗？",
            "### Codex Gauge 会读取浏览器 Cookie 吗？",
            "### Codex Gauge 会读取 `~/.codex/auth.json` 吗？",
            "### 这会触发 5 小时窗口吗？",
        ]:
            self.assertIn(phrase, readme)
        self.assertNotIn("作者其他项目", readme)
        self.assertNotIn("给个 Star", readme)

    def test_public_privacy_doc_exists(self):
        privacy = pathlib.Path("docs/PRIVACY.md").read_text(encoding="utf-8")

        self.assertIn("Codex Gauge Privacy Notes", privacy)
        self.assertIn("does not read browser cookies", privacy)
        self.assertIn("does not read `~/.codex/auth.json`", privacy)
        self.assertIn("bounded recent Codex session `rate_limits` metadata", privacy)
        self.assertIn("labels that data as Snapshot", privacy)
        self.assertIn("Codex app-server", privacy)
        self.assertIn("~/Library/LaunchAgents/app.codexgauge.menubar.plist", privacy)


if __name__ == "__main__":
    unittest.main()
