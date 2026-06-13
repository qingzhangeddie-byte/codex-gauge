# Publishing Codex Gauge Safely

This project publishes one supported surface: the native Codex Gauge menu bar app. It is Codex-only and bundles `native/codex_status.py` inside the app. It does not read browser sessions or `~/.codex/auth.json`. When app-server is unavailable, it can read bounded recent Codex session `rate_limits` metadata as a local snapshot fallback and labels that state as Snapshot.

## Privacy

- Review the diff before each public release.
- Do not publish logs, screenshots with account details, `.venv`, `.env`, `.app` bundles, or files from `~/Library/Application Support/CodexGauge`. In release review, search for the exact rule: do not publish logs.
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

This builds `native/dist/release/CodexGauge-$APP_VERSION.zip`, writes `CodexGauge-$APP_VERSION.zip.sha256`, and includes `Install Codex Gauge.command` plus `README-INSTALL.txt`. The package contains the app bundle and installer only; it must not include logs, source checkout files, local support data, or files from `~/Library/Application Support/CodexGauge`.

The generated package is ad-hoc signed and not notarized until Developer ID signing is configured. Treat it as a source-built convenience package, not the final 1.0 distribution path.

## Reliability Soak

```bash
./script/soak_check.sh --iterations 12 --interval 300
```

The soak checker samples the same bundled helper with `--status-json`, writes JSONL under `~/Library/Application Support/CodexGauge`, and summarizes `source_counts` plus `unavailable_count`. For a release candidate, run a longer soak such as `--iterations 2016 --interval 300` to cover one week.

## Signing

The local build uses ad-hoc `codesign --force --sign -` so it can run on the current Mac. Public distribution should use an Apple Developer ID certificate and notarization:

```bash
codesign --force --options runtime --timestamp --sign "Developer ID Application: YOUR NAME" native/dist/CodexGauge.app
ditto -c -k --keepParent native/dist/CodexGauge.app CodexGauge.zip
xcrun notarytool submit CodexGauge.zip --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple native/dist/CodexGauge.app
```

Do not commit signing identities, notary profiles, API keys, or generated archives.

## Homebrew

A Homebrew cask is a good public install path after signing and notarization. Keep it in a separate tap or release branch and point it at a signed, notarized archive. The cask should install only `CodexGauge.app`; it should not install local logs or development files.

## Release Checklist

1. Run `./script/release_check.sh`.
2. Confirm live data is labeled Live and fallback data is labeled Snapshot.
3. Confirm runtime logs are rotated locally and not packaged.
4. Run `./script/package_release.sh` and verify the zip plus checksum.
5. Create tag `v0.5.0` on the public clean-history commit.
6. Sign and notarize with external credentials.
7. Publish a zipped app bundle or DMG.
8. Update the Homebrew cask checksum.

## Fresh Public Repository Checklist

- Publish from a clean orphan history, not from the legacy fork history.
- Point the clean repo remote at `git@github.com:qingzhangeddie-byte/codex-gauge.git`.
- Push with `git push -u origin main --tags` only after the GitHub repo is a fresh non-fork repo.
- Verify `git clone https://github.com/qingzhangeddie-byte/codex-gauge.git` works before announcing.
- Create the GitHub Release for `v0.5.0`; the README release badge should not point at an older identity.
- Set GitHub About description: `Unofficial macOS menu bar app showing your OpenAI Codex usage: 5-hour and 7-day rate-limit quota at a glance`.
- Set GitHub topics: `macos`, `menubar`, `menu-bar-app`, `codex`, `openai`, `swift`, `rate-limit`, `usage-monitor`, `developer-tools`.
- Upload `docs/assets/codex-gauge-social-preview.png` as the repository social preview.
- Enable private vulnerability reporting in GitHub Settings > Security.
- Delete or archive the old fork only after the fresh repo and release are verified.
