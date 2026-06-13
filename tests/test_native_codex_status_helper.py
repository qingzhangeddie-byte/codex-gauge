import contextlib
import datetime
import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
from unittest import mock


HELPER_PATH = pathlib.Path("native/codex_status.py")


def load_helper():
    spec = importlib.util.spec_from_file_location("native_codex_status", HELPER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class NativeCodexStatusHelperTests(unittest.TestCase):
    def test_helper_avoids_browser_cookies_auth_files_and_claude(self):
        source = HELPER_PATH.read_text()

        forbidden = [
            "browser_cookie3",
            "auth.json",
            "Cookie",
            "Authorization",
            "Claude",
            "claude",
        ]
        for token in forbidden:
            self.assertNotIn(token, source)

    def test_helper_uses_codex_gauge_public_identity(self):
        source = HELPER_PATH.read_text()

        self.assertIn("CODEX_GAUGE_CODEX_CLI_PATH", source)
        self.assertIn('"codex-gauge"', source)
        self.assertIn('"Codex Gauge"', source)
        self.assertNotIn("AI_LIMIT_CODEX_CLI_PATH", source)
        self.assertNotIn('"ai-limit"', source)

    def test_builds_codex_json_snapshot_from_live_rate_limits(self):
        helper = load_helper()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value={
            "plan": "pro",
            "resets_at": 1_800_000_000,
            "primary": {"percent_used": 27, "resets_at": 1_800_000_100},
            "secondary": {"percent_used": 11, "resets_at": 1_800_000_200},
        }):
            snapshot = helper.build_status_snapshot()

        self.assertEqual(snapshot["codex"]["service"], "Codex")
        self.assertTrue(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["five_hour_left"], 73)
        self.assertEqual(snapshot["codex"]["seven_day_left"], 89)
        self.assertEqual(snapshot["codex"]["five_hour_reset"], 1_800_000_100)
        self.assertEqual(snapshot["codex"]["seven_day_reset"], 1_800_000_200)
        self.assertEqual(snapshot["codex"]["plan"], "pro")
        self.assertEqual(snapshot["codex"]["source"], "live")

    def test_live_rate_limits_are_cached_for_short_outages(self):
        helper = load_helper()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value={
            "plan": "pro",
            "primary": {"percent_used": 27, "resets_at": 1_800_000_100},
            "secondary": {"percent_used": 11, "resets_at": 1_800_000_200},
        }), mock.patch.object(helper, "_write_last_live_rate_limits_cache", create=True) as write_cache:
            snapshot = helper.build_status_snapshot()

        self.assertTrue(snapshot["codex"]["ok"])
        write_cache.assert_called_once()

    def test_uses_recent_last_live_cache_when_live_and_snapshot_are_unavailable(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T17:40:00+00:00").timestamp()

        with tempfile.TemporaryDirectory() as tmp:
            support_dir = pathlib.Path(tmp)
            cache_path = support_dir / "last-live-status.json"
            cache_path.write_text(
                json.dumps({
                    "captured_at": "2026-06-12T17:35:00.000Z",
                    "rate_limits": {
                        "limit_id": "codex",
                        "primary": {"used_percent": 36, "resets_at": now + 3600},
                        "secondary": {"used_percent": 60, "resets_at": now + 86400},
                        "plan_type": "pro",
                    },
                }),
                encoding="utf-8",
            )

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper, "latest_local_codex_rate_limits_snapshot", return_value=None), \
                 mock.patch.dict(helper.os.environ, {"CODEX_GAUGE_SUPPORT_DIR": str(support_dir)}), \
                 mock.patch.object(helper.time, "time", return_value=now):
                snapshot = helper.build_status_snapshot()

        self.assertTrue(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["five_hour_left"], 64)
        self.assertEqual(snapshot["codex"]["seven_day_left"], 40)
        self.assertEqual(snapshot["codex"]["source"], "last_live")
        self.assertEqual(snapshot["codex"]["data_time"], "2026-06-12T17:35:00.000Z")
        self.assertIn("showing last live", snapshot["codex"]["error"])

    def test_rejects_old_last_live_cache(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T18:30:00+00:00").timestamp()

        with tempfile.TemporaryDirectory() as tmp:
            support_dir = pathlib.Path(tmp)
            (support_dir / "last-live-status.json").write_text(
                json.dumps({
                    "captured_at": "2026-06-12T17:35:00.000Z",
                    "rate_limits": {
                        "limit_id": "codex",
                        "primary": {"used_percent": 36, "resets_at": now + 3600},
                        "secondary": {"used_percent": 60, "resets_at": now + 86400},
                        "plan_type": "pro",
                    },
                }),
                encoding="utf-8",
            )

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper, "latest_local_codex_rate_limits_snapshot", return_value=None), \
                 mock.patch.dict(helper.os.environ, {"CODEX_GAUGE_SUPPORT_DIR": str(support_dir)}), \
                 mock.patch.object(helper.time, "time", return_value=now):
                snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])

    def test_missing_live_data_returns_clear_diagnostic(self):
        helper = load_helper()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value=None), \
             mock.patch.object(helper, "latest_last_live_rate_limits_cache", return_value=None), \
             mock.patch.object(helper, "latest_local_codex_rate_limits_snapshot", return_value=None):
            snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertIn("Codex", snapshot["codex"]["error"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])

    def test_falls_back_to_recent_codex_session_rate_limit_snapshot(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-11T20:19:00+00:00").timestamp()

        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            session_dir = home / ".codex" / "sessions" / "2026" / "06" / "12"
            session_dir.mkdir(parents=True)
            session_path = session_dir / "rollout.jsonl"
            session_path.write_text(
                json.dumps({
                    "timestamp": "2026-06-11T20:18:00.000Z",
                    "type": "event_msg",
                    "payload": {
                        "type": "token_count",
                        "rate_limits": {
                            "limit_id": "codex",
                            "primary": {
                                "used_percent": 14,
                                "window_minutes": 300,
                                "resets_at": 1_800_000_100,
                            },
                            "secondary": {
                                "used_percent": 21,
                                "window_minutes": 10080,
                                "resets_at": 1_800_000_200,
                            },
                            "plan_type": "pro",
                        },
                    },
                }) + "\n",
                encoding="utf-8",
            )
            os.utime(session_path, (now, now))

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper.pathlib.Path, "home", return_value=home), \
                 mock.patch.object(helper.time, "time", return_value=now):
                snapshot = helper.build_status_snapshot()

        self.assertTrue(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["five_hour_left"], 86)
        self.assertEqual(snapshot["codex"]["seven_day_left"], 79)
        self.assertEqual(snapshot["codex"]["five_hour_reset"], 1_800_000_100)
        self.assertEqual(snapshot["codex"]["seven_day_reset"], 1_800_000_200)
        self.assertEqual(snapshot["codex"]["plan"], "pro")
        self.assertEqual(snapshot["codex"]["source"], "local_snapshot")
        self.assertEqual(snapshot["codex"]["data_time"], "2026-06-11T20:18:00.000Z")

    def test_local_snapshot_rejects_old_capture_even_when_reset_is_future(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T17:30:00+00:00").timestamp()

        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            session_dir = home / ".codex" / "sessions" / "2026" / "06" / "12"
            session_dir.mkdir(parents=True)
            session_path = session_dir / "rollout.jsonl"
            session_path.write_text(
                json.dumps({
                    "timestamp": "2026-06-12T15:44:07.931Z",
                    "rate_limits": {
                        "limit_id": "codex",
                        "primary": {
                            "used_percent": 1,
                            "window_minutes": 300,
                            "resets_at": now + 2 * 60 * 60,
                        },
                        "secondary": {
                            "used_percent": 49,
                            "window_minutes": 10080,
                            "resets_at": now + 6 * 24 * 60 * 60,
                        },
                        "plan_type": "pro",
                    },
                }) + "\n",
                encoding="utf-8",
            )
            os.utime(session_path, (now, now))

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper.pathlib.Path, "home", return_value=home), \
                 mock.patch.object(helper.time, "time", return_value=now):
                snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])
        self.assertIn("Codex live usage unavailable", snapshot["codex"]["error"])

    def test_local_snapshot_accepts_valid_seven_day_when_five_hour_is_stale(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T08:01:00+00:00").timestamp()

        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            session_dir = home / ".codex" / "sessions" / "changed" / "layout" / "deeper" / "still-works"
            session_dir.mkdir(parents=True)
            session_path = session_dir / "rollout.jsonl"
            session_path.write_text(
                json.dumps({
                    "timestamp": "2026-06-12T08:00:00.000Z",
                    "rate_limits": {
                        "limit_id": "codex",
                        "primary": {
                            "used_percent": 14,
                            "window_minutes": 300,
                            "resets_at": 1_600_000_000,
                        },
                        "secondary": {
                            "used_percent": 21,
                            "window_minutes": 10080,
                            "resets_at": 1_800_000_200,
                        },
                        "plan_type": "pro",
                    },
                }) + "\n",
                encoding="utf-8",
            )
            os.utime(session_path, (now, now))

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper.pathlib.Path, "home", return_value=home), \
                 mock.patch.object(helper.time, "time", return_value=now):
                snapshot = helper.build_status_snapshot()

        self.assertTrue(snapshot["codex"]["ok"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertEqual(snapshot["codex"]["seven_day_left"], 79)
        self.assertIsNone(snapshot["codex"]["five_hour_reset"])
        self.assertEqual(snapshot["codex"]["seven_day_reset"], 1_800_000_200)
        self.assertEqual(snapshot["codex"]["source"], "local_snapshot")
        self.assertEqual(snapshot["title"], "5h --  7d 79%")

    def test_local_snapshot_rejects_when_all_reset_windows_are_stale(self):
        helper = load_helper()

        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            session_dir = home / ".codex" / "sessions" / "any-layout"
            session_dir.mkdir(parents=True)
            (session_dir / "rollout.jsonl").write_text(
                json.dumps({
                    "timestamp": "2026-06-12T08:00:00.000Z",
                    "rate_limits": {
                        "limit_id": "codex",
                        "primary": {"used_percent": 14, "resets_at": 1_600_000_000},
                        "secondary": {"used_percent": 21, "resets_at": 1_600_000_100},
                        "plan_type": "pro",
                    },
                }) + "\n",
                encoding="utf-8",
            )

            with mock.patch.object(helper, "live_codex_rate_limits", side_effect=helper.CodexRemoteError("boom")), \
                 mock.patch.object(helper.pathlib.Path, "home", return_value=home), \
                 mock.patch.object(helper.time, "time", return_value=1_700_000_000):
                snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])
        self.assertIn("Codex live usage unavailable", snapshot["codex"]["error"])

    def test_helper_prefers_stdio_app_server_for_native_launch_context(self):
        source = HELPER_PATH.read_text()

        self.assertIn('"stdio://"', source)
        self.assertIn("_read_codex_rate_limits_stdio", source)
        self.assertLess(
            source.index("_read_codex_rate_limits_stdio"),
            source.index("_read_codex_rate_limits_ws"),
        )

    def test_codex_subprocess_env_strips_python_launcher_build_vars(self):
        helper = load_helper()

        with mock.patch.dict(helper.os.environ, {
            "CODEX_HOME": "/tmp/codex-home",
            "HOME": "/Users/example",
            "LOGNAME": "example",
            "PATH": "/custom/bin:/usr/bin",
            "SDKROOT": "/Applications/Xcode.app/SDK",
            "CPATH": "/usr/local/include",
            "LIBRARY_PATH": "/usr/local/lib",
            "__PYVENV_LAUNCHER__": "/Applications/Xcode.app/python3",
        }, clear=True):
            env = helper.codex_subprocess_env()

        self.assertEqual(env["CODEX_CI"], "1")
        self.assertEqual(env["CODEX_SHELL"], "1")
        self.assertEqual(env["CODEX_HOME"], "/tmp/codex-home")
        self.assertEqual(env["PATH"], "/custom/bin:/usr/bin")
        self.assertNotIn("SDKROOT", env)
        self.assertNotIn("CPATH", env)
        self.assertNotIn("LIBRARY_PATH", env)
        self.assertNotIn("__PYVENV_LAUNCHER__", env)

    def test_helper_rejects_non_codex_bucket_when_bucket_map_exists(self):
        helper = load_helper()

        response = {
            "rateLimits": {
                "limitId": "default",
                "limitName": "ChatGPT",
                "primary": {"usedPercent": 1},
            },
            "rateLimitsByLimitId": {
                "chatgpt": {
                    "limitId": "chatgpt",
                    "limitName": "ChatGPT",
                    "primary": {"usedPercent": 1},
                }
            },
        }

        self.assertEqual(helper._select_codex_rate_limits(response), {})

    def test_helper_terminates_app_server_process_groups(self):
        source = HELPER_PATH.read_text()

        self.assertIn("start_new_session=True", source)
        self.assertIn("os.killpg", source)
        self.assertIn("_terminate_process_group", source)
        self.assertNotIn("if proc.poll() is not None:\n        return", source)

    def test_main_accepts_status_json_flag(self):
        helper = load_helper()
        snapshot = {"title": "5h 90%  7d 80%", "codex": {"ok": True}}

        with mock.patch.object(helper, "build_status_snapshot", return_value=snapshot) as build:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                result = helper.main(["--status-json"])

        self.assertEqual(result, 0)
        build.assert_called_once_with()
        self.assertEqual(json.loads(out.getvalue()), snapshot)

    def test_main_rejects_unknown_args(self):
        helper = load_helper()

        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            with self.assertRaises(SystemExit) as raised:
                helper.main(["--unknown"])

        self.assertNotEqual(raised.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
