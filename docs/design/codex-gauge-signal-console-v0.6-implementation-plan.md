# Signal Console v0.6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or equivalent inline execution. Steps use checkbox syntax for tracking.

**Goal:** Implement the selected Signal Console UX so Codex Gauge visibly explains live, cached, snapshot, and unavailable states in the installed macOS menu bar app.

**Architecture:** Keep the existing single-file AppKit app for this release to avoid a risky refactor. Add focused helpers inside `native/CodexGauge.swift` for source state presentation, bounded local history, setup doctor checks, diagnostics copy, and preferences controls. Keep `native/codex_status.py` as the only status source.

**Tech Stack:** Swift/AppKit, UserNotifications, shell build scripts, Python unittest static/regression checks.

---

## Files

- Modify `native/CodexGauge.swift`: Signal Console UI behavior, history, doctor, diagnostics, preferences polish.
- Modify `script/build_and_run.sh`: bump `APP_VERSION` to `0.6.0`.
- Modify `script/release_check.sh`: expect bundle version `0.6.0`.
- Modify `script/replace_installed_app.sh`: accept installed version `0.6.0`.
- Modify `CHANGELOG.md`: add `v0.6.0`.
- Modify `README.md` and `README.zh-CN.md`: describe Signal Console, Setup Doctor, history, diagnostics.
- Modify tests under `tests/`: add static gates for the new UI/data-safety behavior.

## Tasks

- [ ] Add failing tests for source-state copy, unavailable/stalled state, mini history, setup doctor, diagnostics export, preferences polish, and version bump.
- [ ] Implement minimal native code to pass those tests without changing helper privacy boundaries.
- [ ] Build with `./script/build_and_run.sh --build-only`.
- [ ] Run `./script/release_check.sh`.
- [ ] Reinstall with `./script/replace_installed_app.sh`.
- [ ] Verify installed version, LaunchAgent process, and live helper output.
- [ ] Commit locally. Do not push.
