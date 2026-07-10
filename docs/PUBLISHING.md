# Publishing Codex Gauge Safely

This project publishes one supported surface: the native Codex Gauge menu bar app. It is Codex-only and bundles `native/codex_status.py` inside the app. It does not read browser sessions or `~/.codex/auth.json`. The app keeps only its startup LaunchAgent locally, with no support-folder logs, quota caches, histories, reports, or saved refresh preferences.

## Privacy

- Review the diff before each public release.
- Do not publish logs, screenshots with account details, `.venv`, `.env`, `.app` bundles, or legacy files from `~/Library/Application Support/CodexGauge`. In release review, search for the exact rule: do not publish logs.
- Regenerate public screenshots from the checked-in scripts. README and GitHub hero images must use static sample values, not personal live account timing.
- Do not include personal paths from `Info.plist`; the installed app should resolve its helper from `Contents/Resources`.
- Keep private planning notes out of the public repo.
- Keep the public repo identity independent from older fork wording, while preserving required license history.

## Local Release Check

```bash
./script/release_check.sh
```

This runs the unit tests, builds the app, verifies a clean no-xattr app copy with `codesign`, checks version metadata, verifies public image dimensions, and scans for blocked private or legacy files.

## Package Release

```bash
./script/package_release.sh
```

This builds `native/dist/release/CodexGauge-$APP_VERSION.zip`, `native/dist/release/CodexGauge-$APP_VERSION.dmg`, and matching `.sha256` files. The package includes `Install Codex Gauge.command` plus `README-INSTALL.txt`. It contains the app bundle and installer only; it must not include logs, source checkout files, local support data, or files from `~/Library/Application Support/CodexGauge`. The installer launches the app and writes `~/Library/LaunchAgents/app.codexgauge.menubar.plist` for startup login.

The generated package is ad-hoc signed and not notarized until Developer ID signing is configured. Treat it as a source-built convenience package, not the final 1.0 distribution path.

## Reliability Soak

```bash
./script/soak_check.sh --iterations 12 --interval 300
```

The soak checker samples the same live-only bundled helper with `--status-json`, writes JSONL to `${TMPDIR:-/tmp}` unless `--out` is provided, and summarizes `source_counts` plus `unavailable_count`. For a release candidate, run a longer soak such as `--iterations 2016 --interval 300` to cover one week.

## Signing

The local build uses ad-hoc `codesign --force --sign -` so it can run on the current Mac. Public distribution should use an Apple Developer ID certificate and notarization:

```bash
export CODEX_GAUGE_UPDATE_TEAM_ID="YOURTEAMID"
./script/build_and_run.sh --build-only
codesign --force --options runtime --timestamp --sign "Developer ID Application: YOUR NAME" native/dist/CodexGauge.app
ditto -c -k --keepParent native/dist/CodexGauge.app CodexGauge.zip
xcrun notarytool submit CodexGauge.zip --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple native/dist/CodexGauge.app
```

`CODEX_GAUGE_UPDATE_TEAM_ID` is stamped into `CodexGaugeUpdateTeamID` and is required for in-app **Download & Install**. Without it, local ad-hoc builds can still check releases, but automatic update installation refuses to trust a generic signed app.

Do not commit signing identities, notary profiles, API keys, or generated archives.

## Homebrew

A Homebrew cask is a good public install path after signing and notarization. Keep it in a separate tap or release branch and point it at a signed, notarized archive. The cask should install only `CodexGauge.app`; it should not install local logs or development files.

## Release Checklist

1. Run `./script/release_check.sh`.
2. Confirm live data is labeled Live and unavailable data asks the user to open Codex.
3. Confirm startup login creates only `~/Library/LaunchAgents/app.codexgauge.menubar.plist` and no support-folder logs, caches, histories, reports, or saved refresh preferences.
4. Run `./script/package_release.sh` and verify the zip, DMG, and checksum files.
5. Create tag `v0.9.4` on the public clean-history commit.
6. Sign and notarize with external credentials.
7. Publish the zipped app bundle and DMG.
8. Update the Homebrew cask checksum.

## Fresh Public Repository Checklist

- Publish from a clean orphan history, not from the legacy fork history.
- Point the clean repo remote at `git@github.com:qingzhangeddie-byte/codex-gauge.git`.
- Push with `git push -u origin main --tags` only after the GitHub repo is a fresh non-fork repo.
- Verify `git clone https://github.com/qingzhangeddie-byte/codex-gauge.git` works before announcing.
- Create the GitHub Release for `v0.9.4`; the README release badge should not point at an older identity.
- Set GitHub About description: `Calm macOS menu bar gauge for OpenAI Codex usage: 5h/7d horizontal bars, live reset countdowns, local-only diagnostics`.
- Set GitHub topics: `macos`, `menubar`, `menu-bar-app`, `codex`, `openai`, `swift`, `rate-limit`, `usage-monitor`, `developer-tools`.
- Upload the refreshed `docs/assets/codex-gauge-social-preview.png` as the repository social preview after confirming it uses sample values only. Use `docs/assets/codex-gauge-github-hero.png` at the top of README and release notes.
- Enable private vulnerability reporting in GitHub Settings > Security.
- Delete or archive the old fork only after the fresh repo and release are verified.
