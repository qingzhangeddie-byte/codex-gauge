# Codex Gauge

![Codex Gauge GitHub 渲染主图：系统监控风格菜单栏横向额度条](docs/assets/codex-gauge-github-hero.png)

_公开渲染图使用静态示例数值；安装后的 App 会显示你的实时 Codex 使用百分比、横向条和重置倒计时。_

[English](README.md) | 中文说明

Codex Gauge 是一个**安静、安全的 Codex 菜单栏额度仪表**，用于在 macOS 菜单栏直接查看 Codex 5 小时额度、7 天额度和实时重置倒计时。

它是非官方本地工具，重点不是做大而全的 dashboard，而是把最常看的信息放到菜单栏：现在还剩多少 Codex。它也可以理解为一个本地的 Codex rate limit tracker，关注 5 小时窗口、7 天额度和重置时间。

不用再猜自己还剩多少 Codex。

Codex Gauge 会把 Codex 5 小时和 7 天使用百分比、横向条和重置倒计时直接放进 macOS 菜单栏；需要更多细节时，点开 Signal Console 就能看到完整状态和数据来源。

打开一次 ChatGPT 后保持 Codex Gauge 运行，菜单栏就会自动刷新，不需要额外设置浏览器或复制登录信息。

不读取浏览器 Cookie，不读取 `~/.codex/auth.json`，不记录 prompt 或 response 内容。

从源码安装只需要一条命令：

```bash
bash install.sh
```

它和其他工具最大的不同：

- 只做一件事：让 Codex 额度一眼可见。
- 菜单栏优先，只有点开时才显示更完整的 Signal Console。
- 使用克制的系统监控风格横向条，不把状态栏做成吵闹的小 dashboard。
- 紧凑的 Signal Console 清楚标注 Live 和 ChatGPT unavailable 状态。
- 不读取 Codex session 文件，也不保存额度历史、report 或日志。

![Codex Gauge 静态示例菜单栏：横向额度条和重置倒计时](docs/assets/codex-gauge-menubar-live.png)

_菜单栏条形渲染图。这里是静态示例数值；安装后的 App 会实时更新。_

## 核心特点

- 菜单栏同时显示 5 小时和 7 天使用百分比、横向条，以及刷新倒计时
- 系统监控风格的横向条让菜单栏里的额度健康状态更直观，同时不会变成很占位置的大组件
- 紧凑的 Signal Console 显示实时额度、重置时间、数据新鲜度和必要操作
- Signal Console 显示真实的下次刷新倒计时，不再只是静态刷新标签
- 三套可选主题：默认 Blue Ceramic，并提供 Signal Dark 和 Mono Graphite
- 首次运行设置页会解释本地优先模式，并引导新用户打开 Codex、运行 Setup Doctor、开始使用菜单栏
- Preferences 和 Setup Doctor 会跟随当前选择的 Signal Console 主题
- 数据只从本地 Codex app-server 实时读取，不会扫描 Codex session 文件作为 fallback
- 自适应刷新：正常 5 分钟，偏低 3 分钟，严重偏低 2 分钟，临时错误后 1 分钟重试
- 主题和刷新频率偏好只在当前运行会话中生效；开机启动使用标准 macOS LaunchAgent 保存
- 可选通知：5 小时额度偏低、额度恢复、长时间非实时数据都会提醒
- Signal Console 会在弹出面板解释 Live、ChatGPT unavailable 和不可用状态
- Signal Console 和 tooltip 会解释 Live 和 Open ChatGPT，不会把存储值当成当前实时数据
- Setup Doctor 和 Copy Diagnostics 可帮助排查本地设置，但不会复制 prompts、Cookie、auth 文件或日志
- 原生 App 自带 helper，安装后不依赖源码目录
- 不保存额度历史、缓存、report 或运行日志文件；开机启动只使用标准 LaunchAgent
- 原生菜单栏 App 不读取浏览器 Cookie
- 原生菜单栏 App 不读取 `~/.codex/auth.json`

![Codex Gauge Signal Console](docs/assets/codex-gauge-signal-console.png)

上面的 Signal Console 截图由真实 macOS 原生界面渲染生成，但使用 README 静态示例额度数值，不是实时账户数据；安装后的 App 会把使用百分比、横向条和重置倒计时放在菜单栏，并在弹出面板里显示更完整的 Codex 细节。

## 紧凑菜单栏

紧凑菜单栏仪表使用透明系统监控风格：左侧显示使用百分比和细横向条，右侧显示重置倒计时文字；没有胶囊背景、分割线、来源竖条或端点圆点。

公开截图使用生成的示例数值，避免暴露具体账户时间；真实菜单栏倒计时会实时更新。

两行分别是 5 小时使用量和 7 天使用量。倒计时区域显示 5 小时重置和 7 天重置。系统监控横向条使用自适应文字、蓝色填充和安静的空轨道，让 Codex Gauge 在浅色或深色菜单栏背景上都清晰可读。

## 快速安装

从本地 clone 安装：

```bash
git clone https://github.com/qingzhangeddie-byte/codex-gauge.git
cd codex-gauge
bash install.sh
```

安装位置：

```text
/Applications/CodexGauge.app
```

通常约一分钟后，菜单栏会出现 Codex 额度仪表。

安装脚本会直接启动 App，并写入 `~/Library/LaunchAgents/app.codexgauge.menubar.plist`，下次登录 macOS 时会自动打开 Codex Gauge。从菜单里选择 **Quit** 会停止当前菜单栏 App。

从下载好的 release package 安装时，打开 `Install Codex Gauge.command`。

安装后，菜单里的 **Check for Updates...** 会查询 GitHub Releases 的 latest 版本，并展示当前版本、最新版本、release 信息和更新说明。更新提示提供三个选择：**Install Update**、**Skip this version**、**Remind me later**。跳过只在当前 App 会话中生效，避免同一 release 反复提示。发现新版本 zip 时，**Install Update** 会把更新包下载到临时目录，验证 release checksum、固定的发布者 Team ID 和 notarization，再替换 `CodexGauge.app` 并重新启动。Codex Gauge 不保存更新历史、skipped-version records 或 updater cache。

维护者生成 package 时使用：

```bash
./script/package_release.sh
open native/dist/release
```

生成的 release 输出包含 zip、DMG、`CodexGauge.app`、`Install Codex Gauge.command` 和 SHA-256 checksum 文件。正式 1.0 公共版本应使用 Developer ID 签名、notarization，并在构建时设置 `CODEX_GAUGE_UPDATE_TEAM_ID`，这样 app 内安装才能验证发布者。

## 和其他工具的不同

| 方向 | Codex Gauge |
|---|---|
| 菜单栏安全性 | 原生菜单栏 App 不读取浏览器 Cookie |
| 本地登录安全性 | 原生菜单栏 App 不读取 `~/.codex/auth.json` |
| 打包方式 | helper 打包在 App bundle 内部 |
| 菜单栏常驻 | 通过用户级 LaunchAgent 登录时自动启动 |
| 更新 | 手动检查 GitHub release，确认后 Install Update，只使用临时文件 |
| 信息密度 | 同时展示 5 小时和 7 天额度 |
| 刷新策略 | 根据额度余量自适应刷新：正常 5 分钟，偏低 3 分钟，严重偏低 2 分钟，临时错误后快速重试 |
| 偏好设置 | 当前会话内的刷新频率、通知和主题控制 |
| 通知 | 只在用户主动开启后提醒关键额度状态 |
| Signal Console | 直接说明数据是实时还是不可用 |
| Setup Doctor | 检查 Codex App、helper、实时数据、开机启动状态和通知权限 |
| Diagnostics | 安全复制诊断信息，不包含 prompts、Cookie、auth 文件、session 内容、历史、缓存、report 或日志 |
| 重置时间 | 下拉菜单直接显示重置时间 |
| 安装方式 | 本地 clone 后一条命令安装，不建议网络管道执行 shell |

## 安全模型

原生菜单栏 App 使用打包在 App 内部的 helper：

```text
CodexGauge.app/Contents/Resources/codex_status.py
```

App 会通过打包的 helper 访问本地 Codex app-server 读取实时额度。整个数据路径只使用实时数据：不会缓存额度，不会创建使用历史文件，也不会扫描 Codex session 文件寻找 fallback。短暂读取失败时，正在运行的 App 最多保留 10 分钟内存中的上一次读数，同时明确显示错误并重试；该读数不会写入硬盘。

它不读取浏览器 Cookie，不读取 `~/.codex/auth.json`，也不扫描无关的项目目录、浏览器 profile 或 Keychain。

注意：Codex app-server 路径可能启动或刷新 Codex 5 小时窗口，因为它和 ChatGPT App 使用同一套本地服务。

更多说明见：[Privacy Notes](docs/PRIVACY.md)、[Security Policy](SECURITY.md) 和 [Changelog](CHANGELOG.md)。

## 环境要求

- macOS 13 或更新版本
- 已安装并登录 ChatGPT App 或 Codex CLI
- 从源码构建需要 Xcode command line tools
- 系统可用 `/usr/bin/python3`

## 安装方式

```bash
bash install.sh
```

安装脚本只构建和替换原生菜单栏 App。它不会安装通用使用量 CLI、浏览器 Cookie helper 或 auth 文件 helper。

## 卸载

先在 Codex Gauge 菜单中选择 **Quit**，然后删除 App 和旧版本可能留下的本地支持文件：

```bash
launchctl bootout "gui/$(id -u)/app.codexgauge.menubar" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
rm -rf /Applications/CodexGauge.app "$HOME/Library/Application Support/CodexGauge"
```

## 从源码构建

```bash
./script/build_and_run.sh --build-only
./script/build_and_run.sh --install
```

检查 bundle：

```bash
plutil -p native/dist/CodexGauge.app/Contents/Info.plist
```

plist 应该只引用 `codex_status.py`，不应该包含你的源码目录路径。

## FAQ

### 如何查看 Codex 还剩多少额度？

安装 Codex Gauge 后，它会在 macOS 菜单栏直接显示 Codex 5 小时和 7 天额度。

### 这是 Codex rate limit tracker 吗？

是。Codex Gauge 专注显示 Codex 额度：5 小时剩余额度、7 天剩余额度和重置时间。

### Codex Gauge 会读取浏览器 Cookie 吗？

不会。原生菜单栏 App 不读取浏览器 Cookie、浏览器 profile、Keychain 或无关项目目录。

### Codex Gauge 会读取 `~/.codex/auth.json` 吗？

不会。App 只使用本地 Codex app-server 获取实时额度，不读取 Codex session 文件、浏览器 Cookie 或 `~/.codex/auth.json`。额度读数只存在内存中，不会缓存到硬盘。

### 这会触发 5 小时窗口吗？

实时 Codex app-server 路径可能启动或刷新 Codex 5 小时窗口，因为它和 ChatGPT App 使用同一套本地服务。

## 开发验证

```bash
python3 -m unittest discover -s tests -v
./script/build_and_run.sh --build-only
./script/release_check.sh
./script/soak_check.sh --iterations 3 --interval 0
```

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
