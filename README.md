# Codex Gauge

[![CI](https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml/badge.svg)](https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml)
[![Latest release](https://img.shields.io/github/v/release/qingzhangeddie-byte/codex-gauge?display_name=tag)](https://github.com/qingzhangeddie-byte/codex-gauge/releases/latest)
[![License](https://img.shields.io/github/license/qingzhangeddie-byte/codex-gauge)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-0f766e)

![Codex Gauge live menu bar](docs/assets/codex-gauge-menubar-live.png)

**A simple, safe macOS menu bar app to check Codex usage, track the Codex 5-hour limit, and watch your Codex 7-day quota at a glance.**

Stop guessing how much Codex you have left.

Codex Gauge puts your 5-hour and 7-day quota directly in the macOS menu bar, with reset countdowns, live-source labels, and a compact Signal Console when you need more detail.

Codex Gauge 会把 Codex 5 小时额度、7 天额度、重置倒计时和数据来源直接放进 macOS 菜单栏；需要更多细节时，点开 Signal Console 就能看到完整状态。

Open Codex once, keep Codex Gauge running, and the menu bar refreshes hands-free.

打开一次 Codex 后保持 Codex Gauge 运行，菜单栏就会自动刷新，不需要额外设置浏览器或复制登录信息。

No browser cookies. No `~/.codex/auth.json`. No prompt or response logging.

不读取浏览器 Cookie，不读取 `~/.codex/auth.json`，不记录 prompt 或 response 内容。

Install from source with one command:

```bash
bash install.sh
```

What makes it different:

- Built for one job: Codex quota at a glance.
- Native menu bar first, detailed Signal Console only when you click.
- Clear labels for Live, Last live, Snapshot, and Codex closed states.
- Local-only diagnostics and reports, designed to avoid private prompt/session content.

Codex Gauge is an **Unofficial** macOS menu bar app for people who use Codex heavily and want a Codex rate limit tracker that stays local.

Codex Gauge 是一个**非官方** macOS 菜单栏工具，适合频繁使用 Codex、想要本地查看 Codex rate limit 的用户。

It shows remaining Codex 5-hour usage and Codex 7-day quota without opening a dashboard, reading browser cookies, or exposing local auth files to a menu bar process.

它可以直接显示 Codex 5 小时剩余额度和 Codex 7 天剩余额度，不需要打开 dashboard，不读取浏览器 Cookie，也不会把本地登录文件暴露给菜单栏进程。

Search phrases this project is designed to answer naturally: **check Codex usage**, **OpenAI Codex usage monitor**, **Codex quota tracker**, **Codex rate limit tracker**, **Codex 5-hour limit**, **Codex 7-day quota**, **macOS Codex menu bar app**, and **Codex usage menubar**.

这个项目自然覆盖的中文搜索词包括：**查看 Codex 使用量**、**Codex 额度监控**、**Codex 菜单栏工具**、**Codex 5 小时限制**、**Codex 7 天额度**、**OpenAI Codex 使用量监控**。

## What You Get

- Compact menu bar gauge for Codex 5-hour and 7-day quota  
  菜单栏紧凑显示 Codex 5 小时额度和 7 天额度
- Segmented live signal rails make quota health readable in the menu bar without widening the app
  分段信号条让菜单栏里的额度健康状态更直观，同时不增加占用宽度
- Custom Signal Console popover with status, quota, reset timing, trend, doctor checks, diagnostics, and actions
  自定义 Signal Console 弹出面板显示状态、额度、重置时间、趋势、诊断检查、安全诊断和操作入口；下拉菜单显示额度重置时间和上次刷新时间
- Signal Console shows the actual next-refresh countdown, not a static refresh label
  Signal Console 显示真实的下次刷新倒计时，不再只是静态刷新标签
- Three selectable themes: Paper Console by default, Signal Dark, and Mono Graphite
  三套可选主题：默认 Paper Console，并提供 Signal Dark 和 Mono Graphite
- First-run setup explains the local-only model and points new users to Codex, Setup Doctor, and the menu bar
  首次运行设置页会解释本地优先模式，并引导新用户打开 Codex、运行 Setup Doctor、开始使用菜单栏
- Preferences and Setup Doctor use the same selected Signal Console theme
  Preferences 和 Setup Doctor 会跟随当前选择的 Signal Console 主题
- Time-based trends show signed 5-hour movement in the current reset window and 7-day movement over the last 24 hours
  趋势不再按模糊样本数展示，而是显示当前 5 小时窗口变化，以及过去 24 小时内的 7 天额度变化，并直接标出正负百分比
- Signal Console shows a local 24-hour quota movement report inline; Copy report never saves a report file
  Signal Console 会直接显示本地 24 小时额度变化报告；Copy report 只复制，不保存报告文件
- Clear local data removes Codex Gauge history, last-live cache, and logs without touching Codex auth/session data
  Clear local data 只清理 Codex Gauge 的历史、Last live 缓存和日志，不触碰 Codex 登录或会话数据
- Adaptive refresh: 5 minutes normally, 3 minutes when low, 2 minutes when critical, 1 minute after transient errors  
  自适应刷新：正常 5 分钟，额度偏低 3 分钟，严重偏低 2 分钟，临时错误后 1 分钟重试
- Preferences for theme, Adaptive, 5-minute, or 10-minute refresh plus launch-at-login control
  偏好设置支持主题、自适应、5 分钟、10 分钟刷新，也可以控制是否登录时启动
- Opt-in notifications for low 5-hour quota, restored quota, and prolonged non-live data
  可选通知：5 小时额度偏低、额度恢复、长时间非实时数据都会提醒
- Signal Console states explain Live, Last live, Snapshot, Codex closed, and unavailable data directly in the popover
  Signal Console 会在弹出面板解释 Live、Last live、Snapshot、Codex closed 和不可用状态
- Menu bar states mark Cache, Snapshot, and Open explicitly so stale data is not confused with Live
  菜单栏会明确标记 Cache、Snapshot 和 Open 状态，避免把非实时数据误认为 Live
- Setup Doctor and Copy Diagnostics help debug local setup without copying prompts, cookies, auth files, or logs
  Setup Doctor 和 Copy Diagnostics 可帮助排查本地设置，但不会复制 prompts、Cookie、auth 文件或日志
- Self-contained app bundle with its helper inside `Contents/Resources`  
  自包含 App bundle，helper 打包在 `Contents/Resources` 内
- User LaunchAgent keeps the installed menu bar app resident without browser-cookie access  
  用户级 LaunchAgent 保持菜单栏 App 常驻，不读取浏览器 Cookie
- Bounded fallback: short **Last live** cache, 15-minute **Snapshot** guard, and visible menu bar source marker  
  有边界的 fallback：短时 **Last live** 缓存、15 分钟 **Snapshot** 新鲜度保护，并在菜单栏显示来源标记
- Runtime logs in `~/Library/Application Support/CodexGauge`, rotated locally  
  运行日志写入 `~/Library/Application Support/CodexGauge`，并在本地轮转

![Codex Gauge Signal Console](docs/assets/codex-gauge-signal-console.png)

This is an actual app-rendered Signal Console screenshot generated from the native macOS view. It uses sample quota values for the README; the installed app shows your local live quota values.

上面的 Signal Console 截图由真实 macOS 原生界面渲染生成，但使用 README 示例额度数值；安装后的 App 会显示你本机的实时额度。

## Four-signal menu bar

![Codex Gauge four-bar mockup](docs/design/codex-gauge-four-bar-mockup.svg)

The compact menu bar gauge uses the selected mood-lane design: one row for 5-hour quota and one row for 7-day quota.

紧凑菜单栏仪表使用 mood-lane 设计：一行显示 5 小时窗口，一行显示 7 天窗口。

The four signals are 5-hour quota left, 5-hour reset countdown, 7-day quota left, and 7-day reset countdown.

四个信号分别是 5 小时额度剩余、5 小时重置倒计时、7 天额度剩余、7 天重置倒计时。

Quota rails use segmented signal cells with a green-to-red health scale; reset lanes move from red through coral and orange into warm yellow.

额度条使用分段信号格，并保留绿色到红色的健康刻度；重置轨道从红色过渡到珊瑚色、橙色，最后变成温暖黄色。

The tiny vector face slides right and morphs from frown to smile as reset approaches, so countdown reads as time movement instead of danger.

小表情是原生绘制的矢量脸，会随着重置临近向右移动，并从皱眉过渡到微笑，所以倒计时读起来是时间移动，不是危险警报。

![Codex Gauge color states](docs/assets/codex-gauge-color-states.svg)

The color-state preview is simulated so the README can show healthy, watch, and critical states without pretending those are your current live quota values.

颜色状态图是模拟示例，用来展示健康、偏低、严重偏低时的视觉变化，不假装这些就是当前实时额度。

## Quick Start

From a local clone:

```bash
git clone https://github.com/qingzhangeddie-byte/codex-gauge.git
cd codex-gauge
bash install.sh
```

That installs the native app at:

```text
/Applications/CodexGauge.app
```

About a minute later, Codex Gauge should appear in your menu bar with live Codex usage.

The installer also writes `~/Library/LaunchAgents/app.codexgauge.menubar.plist` so macOS keeps the menu bar process running. Choosing **Quit** from the menu unloads that LaunchAgent for the current user.

From a downloaded release package, open `Install Codex Gauge.command`.

For maintainers creating that package:

```bash
./script/package_release.sh
open native/dist/release
```

The generated zip includes `CodexGauge.app`, `Install Codex Gauge.command`, and a SHA-256 checksum. Public 1.0 builds should still be Developer ID signed and notarized.

## Why Codex Gauge is different

| Area | Codex Gauge |
|---|---|
| Native menu bar safety | No browser cookies in the menu bar app |
| Local auth safety | No `~/.codex/auth.json` reads in the menu bar app |
| Packaging | Self-contained app bundle with a bundled helper |
| Menu bar persistence | User LaunchAgent with explicit Quit cleanup |
| Signal quality | Shows both 5-hour and 7-day quota instead of one vague number |
| Refresh behavior | Adaptive refresh instead of constant polling: 5 minutes normally, 3 minutes when low, 2 minutes when critical, with quick retry after transient errors |
| Preferences | Built-in refresh cadence, notifications, and launch-at-login controls |
| Notifications | Opt-in alerts for the moments users actually care about |
| Signal Console | Explains whether data is live, cached, snapshot-based, or unavailable |
| Setup Doctor | Local checks for Codex app, helper, live data, LaunchAgent, and notifications |
| Diagnostics | Safe copy-only diagnostics that exclude prompts, cookies, auth files, session contents, and logs |
| Reset timing | Reset timing is visible in the dropdown |
| Setup | Local clone, one install command, no network-piped shell script |

Many usage tools are broad dashboards, token log readers, or browser-session helpers. Codex Gauge is intentionally narrower: it is a small macOS status gauge for the question you ask all day - "how much Codex do I have left?"

很多使用量工具是大而全的 dashboard、token log reader 或浏览器 session helper。Codex Gauge 刻意做得更窄：它只是一个 macOS 状态栏仪表，回答你一天里最常问的问题：“我还剩多少 Codex？”

## SEO Keywords

- OpenAI Codex usage monitor / OpenAI Codex 使用量监控
- Codex quota tracker / Codex 额度监控
- Codex rate limit tracker / Codex rate limit 追踪
- Codex 5-hour limit menu bar / Codex 5 小时限制菜单栏
- Codex 7-day quota monitor / Codex 7 天额度监控
- macOS Codex menu bar app / macOS Codex 菜单栏 App
- safe Codex usage checker / 安全的 Codex 使用量查看工具

## Safety Model

The native menu bar app uses a bundled helper:

```text
CodexGauge.app/Contents/Resources/codex_status.py
```

For live Codex quota, it first talks to the local Codex app-server. Each successful live reading is cached locally for short outages and is labeled **Last live** if reused. If live and last-live data are unavailable, it can fall back to a bounded local snapshot: the helper reads at most 80 recent Codex session files, only the last 2 MB of each file, and extracts only `rate_limits` metadata. Snapshot data must be captured within the last 15 minutes and is labeled as **Snapshot** in the dropdown so stale fallback data is not presented as live.

It does **not** read browser cookies, does **not** read `~/.codex/auth.json`, and does **not** scan unrelated project folders, browser profiles, or Keychain.

Important limitation: the Codex app-server path can start or refresh the Codex 5-hour window because it talks to the same local Codex service used by the Codex desktop app.

More detail: [Privacy Notes](docs/PRIVACY.md), [Security Policy](SECURITY.md), and [Changelog](CHANGELOG.md).

## Requirements

- macOS 13 or newer
- Codex desktop app or Codex CLI installed and signed in
- Xcode command line tools for building from source
- Python 3 available at `/usr/bin/python3`

## Install

```bash
bash install.sh
```

The installer builds and replaces the native menu bar app only. It does not install a broad usage CLI, browser-cookie helper, or auth-file helper.

## Uninstall

Choose **Quit** from the Codex Gauge menu first. Then remove the app and local support files:

```bash
launchctl bootout "gui/$(id -u)/app.codexgauge.menubar" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
rm -rf /Applications/CodexGauge.app "$HOME/Library/Application Support/CodexGauge"
```

## Build From Source

```bash
./script/build_and_run.sh --build-only
./script/build_and_run.sh --install
```

Inspect the bundle:

```bash
plutil -p native/dist/CodexGauge.app/Contents/Info.plist
```

The plist should reference `codex_status.py`, not your source checkout.

## Data Sources

| Data | Source |
|---|---|
| Codex live quota | Local Codex app-server |
| Codex fallback quota | Recent `~/.codex/sessions` `rate_limits` metadata, recursively discovered, bounded by file count and tail size, labeled Snapshot |
| Menu bar persistence | `~/Library/LaunchAgents/app.codexgauge.menubar.plist` |
| Runtime logs | `~/Library/Application Support/CodexGauge`, rotated at 512 KB |

## FAQ

### How do I see how much Codex quota I have left?

Install Codex Gauge and it shows your Codex 5-hour and 7-day quota directly in the macOS menu bar.

### Is this a Codex rate limit tracker?

Yes. Codex Gauge focuses on Codex quota visibility: remaining 5-hour usage, remaining 7-day usage, and reset timing.

### Does Codex Gauge read browser cookies?

No. The native menu bar app does not read browser cookies, browser profiles, Keychain, or unrelated project folders.

### Does Codex Gauge read `~/.codex/auth.json`?

No. It uses the local Codex app-server for live usage and a bounded read-only session metadata fallback labeled Snapshot.

### Does this trigger the 5-hour window?

The live Codex app-server path can start or refresh the Codex 5-hour window because it talks to the same local Codex service used by the Codex desktop app.

## Development Checks

```bash
python3 -m unittest discover -s tests -v
./script/build_and_run.sh --build-only
./script/release_check.sh
./script/soak_check.sh --iterations 3 --interval 0
```

## Public Release Notes

Read [Publishing](docs/PUBLISHING.md) before making a public release. `./script/package_release.sh` creates a zip and checksum for review. Public builds should be signed and notarized with your own Apple Developer credentials. Do not publish generated logs, local app bundles, `.venv`, `.env`, screenshots with account details, or files from `~/Library/Application Support/CodexGauge`.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
