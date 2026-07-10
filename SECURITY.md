# Security Policy

Codex Gauge is a local macOS menu bar utility. It does not provide Codex access, bypass Codex limits, or send usage data to third-party analytics.

## Supported Versions

Security fixes target the latest public release.

## Reporting A Vulnerability

Please open a private GitHub security advisory when available, or contact the maintainer through GitHub if advisories are unavailable. Do not include secrets, tokens, browser cookies, or private session logs in public issues.

## Local Data Boundary

The native app:

- does not read browser cookies;
- does not read `~/.codex/auth.json`;
- does not read Keychain;
- does not scan unrelated project folders;
- reads live Codex quota through a live-only local Codex app-server path;
- does not read Codex session files or keep a disk-backed fallback.
