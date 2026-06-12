# Codex Gauge

[![CI](https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml/badge.svg)](https://github.com/qingzhangeddie-byte/codex-gauge/actions/workflows/test.yml)
[![Latest release](https://img.shields.io/github/v/release/qingzhangeddie-byte/codex-gauge?display_name=tag)](https://github.com/qingzhangeddie-byte/codex-gauge/releases/latest)
[![License](https://img.shields.io/github/license/qingzhangeddie-byte/codex-gauge)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-0f766e)

![Codex Gauge live menu bar](docs/assets/codex-gauge-menubar-live.png)

**A simple, safe macOS menu bar app to check Codex usage, track the Codex 5-hour limit, and watch your Codex 7-day quota at a glance.**

Codex Gauge is an **Unofficial** macOS menu bar app for people who use Codex heavily and want a Codex rate limit tracker that stays local. It shows remaining 5-hour and 7-day quota without opening a dashboard, reading browser cookies, or exposing local auth files to a menu bar process.

## What You Get

- Compact menu bar gauge for Codex 5-hour and 7-day quota
- Dropdown detail view with reset timing and last refresh time
- Adaptive refresh: 5 minutes normally, 3 minutes when low, 2 minutes when critical, 1 minute after transient errors
- Self-contained app bundle with its helper inside `Contents/Resources`
- User LaunchAgent keeps the installed menu bar app resident without browser-cookie access
- Bounded local snapshot fallback with an explicit **Snapshot** label when live data is unavailable
- Runtime logs in `~/Library/Application Support/CodexGauge`, rotated locally

![Codex Gauge menu](docs/assets/codex-gauge-menu.svg)

## Four-signal menu bar

![Codex Gauge four-bar mockup](docs/design/codex-gauge-four-bar-mockup.svg)

The compact menu bar gauge uses the selected mood-lane design: one row for 5-hour quota and one row for 7-day quota. The four signals are 5-hour quota left, 5-hour reset countdown, 7-day quota left, and 7-day reset countdown. Quota rails keep the green-to-red health scale; reset lanes move from red through coral and orange into warm yellow. The tiny vector face slides right and morphs from frown to smile as reset approaches, so countdown reads as time movement instead of danger.

![Codex Gauge color states](docs/assets/codex-gauge-color-states.svg)

The color-state preview is simulated so the README can show healthy, watch, and critical states without pretending those are your current live quota values.

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

## Why Codex Gauge is different

| Area | Codex Gauge |
|---|---|
| Native menu bar safety | No browser cookies in the menu bar app |
| Local auth safety | No `~/.codex/auth.json` reads in the menu bar app |
| Packaging | Self-contained app bundle with a bundled helper |
| Menu bar persistence | User LaunchAgent with explicit Quit cleanup |
| Signal quality | Shows both 5-hour and 7-day quota instead of one vague number |
| Refresh behavior | Adaptive refresh instead of constant polling: 5 minutes normally, 3 minutes when low, 2 minutes when critical, with quick retry after transient errors |
| Reset timing | Reset timing is visible in the dropdown |
| Setup | Local clone, one install command, no network-piped shell script |

Many usage tools are broad dashboards, token log readers, or browser-session helpers. Codex Gauge is intentionally narrower: it is a small macOS status gauge for the question you ask all day - "how much Codex do I have left?"

## Safety Model

The native menu bar app uses a bundled helper:

```text
CodexGauge.app/Contents/Resources/codex_status.py
```

For live Codex quota, it first talks to the local Codex app-server. If that path is unavailable from a LaunchAgent context, it falls back to a bounded local snapshot: the helper reads at most 80 recent Codex session files, only the last 2 MB of each file, and extracts only `rate_limits` metadata. Snapshot data is labeled as **Snapshot** in the dropdown so stale fallback data is not presented as live.

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
```

## Public Release Notes

Read [Publishing](docs/PUBLISHING.md) before making a public release. Public builds should be signed and notarized with your own Apple Developer credentials. Do not publish generated logs, local app bundles, `.venv`, `.env`, screenshots with account details, or files from `~/Library/Application Support/CodexGauge`.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
