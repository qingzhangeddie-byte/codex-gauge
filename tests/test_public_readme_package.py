import pathlib
import unittest


class PublicReadmePackageTests(unittest.TestCase):
    def test_readme_brands_project_as_codex_gauge(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        self.assertTrue(readme.startswith("# Codex Gauge\n"))
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml/badge.svg", readme)
        self.assertIn("https://github.com/qingzhangeddie-byte/codex-gauge/releases/latest", readme)
        self.assertIn("docs/assets/codex-gauge-github-hero.png", readme)
        self.assertIn("docs/assets/codex-gauge-menubar-live.png", readme)
        self.assertIn("A calm, safe macOS menu bar app to check Codex usage", readme)
        self.assertIn("Unofficial", readme)
        self.assertIn("docs/assets/codex-gauge-signal-console.png", readme)
        self.assertIn("actual app-rendered Signal Console", readme)
        self.assertIn("Rendered public image with static sample values.", readme)
        self.assertIn("static sample quota values for the README, not live account data", readme)
        self.assertLess(
            readme.index("docs/assets/codex-gauge-github-hero.png"),
            readme.index("A calm, safe macOS menu bar app"),
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

    def test_readme_front_page_explains_value_before_feature_list(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for phrase in [
            "Stop guessing how much Codex you have left.",
            "Codex Gauge puts your 5-hour and 7-day usage percentages directly in the macOS menu bar",
            "Open Codex once, keep Codex Gauge running, and the menu bar refreshes hands-free.",
            "No browser cookies. No `~/.codex/auth.json`. No prompt or response logging.",
            "Install from source with one command:",
            "bash install.sh",
            "What makes it different",
            "Built for one job: Codex quota at a glance.",
            "Calm Morandi rails instead of a noisy dashboard",
        ]:
            self.assertIn(phrase, readme)

        self.assertLess(readme.index("Stop guessing how much Codex you have left."), readme.index("## What You Get"))
        self.assertLess(readme.index("Install from source with one command:"), readme.index("## What You Get"))

    def test_readme_has_line_by_line_chinese_explanation(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")

        for phrase in [
            "Codex Gauge 是一个**非官方** macOS 菜单栏工具",
            "它可以直接显示 Codex 5 小时剩余额度和 Codex 7 天剩余额度",
            "菜单栏紧凑显示 Codex 5 小时和 7 天使用百分比",
            "下拉菜单显示额度重置时间和上次刷新时间",
            "紧凑菜单栏仪表使用极简 Morandi 设计",
            "重置倒计时胶囊",
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
            "Codex quota at a glance",
            "Morandi rails",
            "Live, Last live, Snapshot, and Codex closed states",
            "Zero persistence mode",
            "Clear legacy data removes old Codex Gauge history",
            "actual next-refresh countdown",
            "Codex closed",
            "Reset timing",
            "directly and removes any old Codex Gauge LaunchAgent plist",
        ]:
            self.assertIn(phrase, readme)

    def test_readmes_explain_uninstall_and_notice(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")
        zh_readme = pathlib.Path("README.zh-CN.md").read_text(encoding="utf-8")

        for phrase in [
            "## Uninstall",
            "launchctl bootout",
            "app.codexgauge.menubar",
            "legacy support files",
            "[NOTICE](NOTICE)",
        ]:
            self.assertIn(phrase, readme)

        for phrase in [
            "## 卸载",
            "launchctl bootout",
            "app.codexgauge.menubar",
            "旧版本可能留下的本地支持文件",
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

    def test_readmes_explain_compact_menu_bar_signal(self):
        readme = pathlib.Path("README.md").read_text(encoding="utf-8")
        zh_readme = pathlib.Path("README.zh-CN.md").read_text(encoding="utf-8")

        for phrase in [
            "Compact menu bar",
            "minimal Morandi design",
            "usage percentage bars on the left",
            "reset countdown pills on the right",
            "5-hour usage and 7-day usage",
            "5-hour reset and 7-day reset",
            "green, blue-grey, taupe, and clay states",
        ]:
            self.assertIn(phrase, readme)

        for phrase in [
            "紧凑菜单栏",
            "极简 Morandi 设计",
            "使用百分比条",
            "重置倒计时胶囊",
            "5 小时使用量和 7 天使用量",
            "5 小时重置和 7 天重置",
            "绿色、蓝灰、灰褐和陶土色状态",
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
        self.assertIn("安静、安全的 Codex 菜单栏额度仪表", readme)
        self.assertIn("实时重置倒计时", readme)
        self.assertIn("Zero persistence 模式", readme)
        self.assertIn("不保留 LaunchAgent", readme)
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
        self.assertIn("zero persistence", privacy)
        self.assertIn("Snapshot fallback is disabled in app mode", privacy)
        self.assertIn("Codex app-server", privacy)
        self.assertIn("does not install a LaunchAgent", privacy)


if __name__ == "__main__":
    unittest.main()
