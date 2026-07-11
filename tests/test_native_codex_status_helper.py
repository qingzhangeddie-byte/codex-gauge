import contextlib
import datetime
import importlib.util
import io
import json
import pathlib
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

    def test_finds_codex_cli_inside_renamed_chatgpt_app(self):
        helper = load_helper()
        chatgpt_cli = "/Applications/ChatGPT.app/Contents/Resources/codex"

        with mock.patch.object(helper.shutil, "which", return_value=None), \
             mock.patch.object(
                 helper.pathlib.Path,
                 "is_file",
                 autospec=True,
                 side_effect=lambda path: str(path) == chatgpt_cli,
             ), \
             mock.patch.object(
                 helper.os,
                 "access",
                 side_effect=lambda path, _mode: str(path) == chatgpt_cli,
             ):
            result = helper.find_codex_cli()

        self.assertEqual(result, chatgpt_cli)

    def test_default_codex_path_includes_renamed_chatgpt_app(self):
        helper = load_helper()

        with mock.patch.dict(helper.os.environ, {}, clear=True):
            env = helper.codex_subprocess_env()

        self.assertTrue(env["PATH"].startswith("/Applications/ChatGPT.app/Contents/Resources:"))

    def test_builds_codex_json_snapshot_from_live_rate_limits(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T17:40:00+00:00").timestamp()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value={
            "plan": "pro",
            "resets_at": now + 3600,
            "primary": {"percent_used": 27, "resets_at": now + 3600},
            "secondary": {"percent_used": 11, "resets_at": now + 24 * 3600},
        }), mock.patch.object(helper.time, "time", return_value=now):
            snapshot = helper.build_status_snapshot()

        self.assertEqual(snapshot["codex"]["service"], "Codex")
        self.assertTrue(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["five_hour_left"], 73)
        self.assertEqual(snapshot["codex"]["seven_day_left"], 89)
        self.assertEqual(snapshot["codex"]["five_hour_reset"], now + 3600)
        self.assertEqual(snapshot["codex"]["seven_day_reset"], now + 24 * 3600)
        self.assertEqual(snapshot["codex"]["plan"], "pro")
        self.assertEqual(snapshot["codex"]["source"], "live")

    def test_live_reset_windows_are_clamped_to_known_window_lengths(self):
        helper = load_helper()
        now = datetime.datetime.fromisoformat("2026-06-12T17:40:00+00:00").timestamp()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value={
            "plan": "pro",
            "primary": {"percent_used": 27, "resets_at": now + 216 * 24 * 3600},
            "secondary": {"percent_used": 11, "resets_at": now + 216 * 24 * 3600},
        }), mock.patch.object(helper.time, "time", return_value=now):
            snapshot = helper.build_status_snapshot()

        self.assertTrue(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["five_hour_left"], 73)
        self.assertEqual(snapshot["codex"]["seven_day_left"], 89)
        self.assertIsNone(snapshot["codex"]["five_hour_reset"])
        self.assertIsNone(snapshot["codex"]["seven_day_reset"])

    def test_live_only_helper_never_writes_or_scans_fallback_files(self):
        source = HELPER_PATH.read_text()

        for token in [
            "last-live-status.json",
            "CODEX_GAUGE_SUPPORT_DIR",
            "CODEX_GAUGE_NO_STORAGE",
            "CODEX_GAUGE_READ_LOCAL_SNAPSHOT",
            "latest_last_live_rate_limits_cache",
            "latest_local_codex_rate_limits_snapshot",
            ".codex\" / \"sessions",
            ".rglob(\"*.jsonl\")",
        ]:
            self.assertNotIn(token, source)

    def test_live_failure_returns_clear_unavailable_status_without_fallback(self):
        helper = load_helper()

        with mock.patch.object(
            helper,
            "live_codex_rate_limits",
            side_effect=helper.CodexRemoteError("offline"),
        ):
            snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertEqual(snapshot["codex"]["source"], "live")
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])
        self.assertIn("Codex live usage unavailable", snapshot["codex"]["error"])

    def test_missing_live_data_returns_clear_diagnostic(self):
        helper = load_helper()

        with mock.patch.object(helper, "live_codex_rate_limits", return_value=None):
            snapshot = helper.build_status_snapshot()

        self.assertFalse(snapshot["codex"]["ok"])
        self.assertIn("Codex", snapshot["codex"]["error"])
        self.assertIsNone(snapshot["codex"]["five_hour_left"])
        self.assertIsNone(snapshot["codex"]["seven_day_left"])

    def test_helper_prefers_stdio_app_server_for_native_launch_context(self):
        source = HELPER_PATH.read_text()

        self.assertIn('"stdio://"', source)
        self.assertIn("_read_codex_rate_limits_stdio", source)
        self.assertLess(
            source.index("_read_codex_rate_limits_stdio"),
            source.index("_read_codex_rate_limits_ws"),
        )

    def test_stdio_app_server_client_sends_initialized_before_rate_limit_request(self):
        helper = load_helper()
        writes = []
        read_response_ids = []
        read_ids_at_rate_limit_write = []

        class FakeStdin:
            def write(self, value):
                message = json.loads(value)
                writes.append(message)
                if message.get("method") == "account/rateLimits/read":
                    read_ids_at_rate_limit_write.append(list(read_response_ids))

            def flush(self):
                pass

        class FakeStdout:
            def __init__(self):
                self.lines = [
                    json.dumps({"id": 1, "result": {"ok": True}}) + "\n",
                    json.dumps({"id": 2, "result": {"summary": {"lifetimeTokens": 123}}}) + "\n",
                    json.dumps({
                        "id": 3,
                        "result": {
                            "rateLimits": {
                                "limitId": "codex",
                                "primary": {"usedPercent": 7, "resetsAt": 1_800_000_120},
                                "secondary": {"usedPercent": 3, "resetsAt": 1_800_086_420},
                                "planType": "pro",
                            }
                        },
                    }) + "\n",
                    json.dumps({
                        "id": 4,
                        "result": {
                            "rateLimits": {
                                "limitId": "codex",
                                "primary": {"usedPercent": 89, "resetsAt": 1_800_000_000},
                                "secondary": {"usedPercent": 42, "resetsAt": 1_800_086_400},
                                "planType": "pro",
                            }
                        },
                    }) + "\n",
                    json.dumps({
                        "id": 5,
                        "result": {
                            "rateLimits": {
                                "limitId": "codex",
                                "primary": {"usedPercent": 89, "resetsAt": 1_800_000_000},
                                "secondary": {"usedPercent": 42, "resetsAt": 1_800_086_400},
                                "planType": "pro",
                            }
                        },
                    }) + "\n",
                ]

            def readline(self):
                line = self.lines.pop(0)
                read_response_ids.append(json.loads(line).get("id"))
                return line

        class FakeProcess:
            pid = 12345

            def __init__(self):
                self.stdin = FakeStdin()
                self.stdout = FakeStdout()

            def poll(self):
                return None

        fake_process = FakeProcess()

        def fake_select(readers, _writers, _errors, _timeout):
            return (readers, [], []) if fake_process.stdout.lines else ([], [], [])

        with mock.patch.object(helper.subprocess, "Popen", return_value=fake_process), \
             mock.patch.object(helper.select, "select", side_effect=fake_select), \
             mock.patch.object(helper, "_terminate_process_group"):
            result = helper._read_codex_rate_limits_stdio("/Applications/Codex.app/Contents/Resources/codex", 5)

        self.assertEqual(result["primary"]["used_percent"], 89)
        self.assertEqual(result["secondary"]["used_percent"], 42)
        self.assertEqual(
            [message.get("method") for message in writes],
            [
                "initialize",
                "notifications/initialized",
                "account/usage/read",
                "account/rateLimits/read",
                "account/rateLimits/read",
                "account/rateLimits/read",
            ],
        )
        self.assertEqual(writes[2]["id"], 2)
        self.assertEqual(writes[3]["id"], 3)
        self.assertEqual(writes[4]["id"], 4)
        self.assertEqual(writes[5]["id"], 5)
        self.assertTrue(all(2 in ids for ids in read_ids_at_rate_limit_write))

    def test_verified_rate_limit_samples_accept_a_real_reset_instead_of_old_usage(self):
        helper = load_helper()
        now = 1_800_000_000
        old_window = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 99,
                "windowDurationMins": 300,
                "resetsAt": now + 30,
            },
            "secondary": {
                "usedPercent": 42,
                "windowDurationMins": 10080,
                "resetsAt": now + 4 * 24 * 60 * 60,
            },
            "planType": "pro",
        }
        new_window = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 2,
                "windowDurationMins": 300,
                "resetsAt": now + 5 * 60 * 60,
            },
            "secondary": {
                "usedPercent": 42,
                "windowDurationMins": 10080,
                "resetsAt": now + 4 * 24 * 60 * 60,
            },
            "planType": "pro",
        }

        merged = helper._merge_remote_rate_limit_samples(
            [old_window, new_window, new_window],
            now=now,
        )

        self.assertEqual(merged["primary"]["used_percent"], 2)
        self.assertEqual(merged["primary"]["resets_at"], now + 5 * 60 * 60)
        self.assertEqual(merged["secondary"]["used_percent"], 42)

    def test_verified_rate_limit_samples_reject_today_stale_five_hour_snapshot(self):
        helper = load_helper()
        now = 1_783_733_300
        current = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 67,
                "windowDurationMins": 300,
                "resetsAt": 1_783_740_401,
            },
            "secondary": {
                "usedPercent": 23,
                "windowDurationMins": 10080,
                "resetsAt": 1_784_309_202,
            },
        }
        stale = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 3,
                "windowDurationMins": 300,
                "resetsAt": 1_783_741_935,
            },
            "secondary": {
                "usedPercent": 2,
                "windowDurationMins": 10080,
                "resetsAt": 1_784_309_464,
            },
        }

        merged = helper._merge_remote_rate_limit_samples(
            [current, current, stale],
            now=now,
        )

        self.assertEqual(merged["primary"]["used_percent"], 67)
        self.assertEqual(merged["primary"]["resets_at"], 1_783_740_401)
        self.assertEqual(merged["secondary"]["used_percent"], 23)

    def test_verified_rate_limit_samples_ignore_an_expired_pre_reset_window(self):
        helper = load_helper()
        now = 1_800_000_000
        expired = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 99,
                "windowDurationMins": 300,
                "resetsAt": now - 120,
            },
        }
        current = {
            "limitId": "codex",
            "primary": {
                "usedPercent": 3,
                "windowDurationMins": 300,
                "resetsAt": now + 5 * 60 * 60,
            },
        }

        merged = helper._merge_remote_rate_limit_samples(
            [expired, current, expired],
            now=now,
        )

        self.assertEqual(merged["primary"]["used_percent"], 3)
        self.assertEqual(merged["primary"]["resets_at"], now + 5 * 60 * 60)

    def test_websocket_app_server_primes_usage_before_reading_rate_limits(self):
        source = HELPER_PATH.read_text()
        body = source.split("def _read_codex_rate_limits_ws", 1)[1].split(
            "def _ws_handshake", 1
        )[0]

        self.assertLess(body.index('"account/usage/read"'), body.index('"account/rateLimits/read"'))
        self.assertIn("RATE_LIMIT_SAMPLE_COUNT", body)
        self.assertIn("_verified_remote_rate_limits(rate_limit_results)", body)

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
