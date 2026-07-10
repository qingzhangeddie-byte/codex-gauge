#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import datetime
import json
import os
import pathlib
import select
import signal
import shutil
import socket
import struct
import subprocess
import sys
import time


REMOTE_TIMEOUT_SEC = 10
RATE_LIMIT_SAMPLE_COUNT = 3
RATE_LIMIT_RESET_JITTER_SEC = 15 * 60
PRIMARY_RESET_MAX_FUTURE_SEC = 6 * 60 * 60
SECONDARY_RESET_MAX_FUTURE_SEC = 8 * 24 * 60 * 60
RESET_FUTURE_GRACE_SEC = 60
ENV_CODEX_CLI_PATH = "CODEX_GAUGE_CODEX_CLI_PATH"
CODEX_GAUGE_CLIENT = {"name": "codex-gauge", "title": "Codex Gauge", "version": "0"}


class CodexRemoteError(Exception):
    pass


def find_free_local_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def find_codex_cli() -> str | None:
    override = os.environ.get(ENV_CODEX_CLI_PATH, "").strip()
    if override:
        expanded = pathlib.Path(override).expanduser()
        if expanded.is_file() and os.access(expanded, os.X_OK):
            return str(expanded)

    found = shutil.which("codex")
    if found:
        return found

    for candidate in (
        pathlib.Path("/Applications/ChatGPT.app/Contents/Resources/codex"),
        pathlib.Path.home() / "Applications/ChatGPT.app/Contents/Resources/codex",
        pathlib.Path("/Applications/Codex.app/Contents/Resources/codex"),
        pathlib.Path.home() / "Applications/Codex.app/Contents/Resources/codex",
    ):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)

    return None


def codex_subprocess_env() -> dict:
    home = str(pathlib.Path.home())
    user = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    return {
        "CODEX_CI": "1",
        "CODEX_HOME": os.environ.get("CODEX_HOME") or str(pathlib.Path(home) / ".codex"),
        "CODEX_SHELL": "1",
        "HOME": os.environ.get("HOME") or home,
        "LOGNAME": os.environ.get("LOGNAME") or user,
        "PATH": os.environ.get("PATH")
        or "/Applications/ChatGPT.app/Contents/Resources:/Applications/Codex.app/Contents/Resources:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "SHELL": os.environ.get("SHELL") or "/bin/zsh",
        "TMPDIR": os.environ.get("TMPDIR") or "/tmp",
        "USER": user,
    }


def _terminate_process_group(proc: subprocess.Popen):
    running = proc.poll() is None
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    except OSError:
        if running:
            proc.terminate()
    if running:
        try:
            proc.wait(timeout=2)
            return
        except subprocess.TimeoutExpired:
            pass
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    except OSError:
        if running:
            proc.kill()
    if running:
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass


def live_codex_rate_limits(timeout: int = REMOTE_TIMEOUT_SEC) -> dict | None:
    codex_cli = find_codex_cli()
    if not codex_cli:
        raise CodexRemoteError(
            "Codex CLI not found. Open ChatGPT or install the Codex CLI."
        )

    try:
        return _read_codex_rate_limits_stdio(codex_cli, timeout)
    except CodexRemoteError as stdio_error:
        websocket_error = stdio_error
    except (OSError, subprocess.SubprocessError) as stdio_error:
        websocket_error = stdio_error

    try:
        port = find_free_local_port()
        proc = subprocess.Popen(
            [codex_cli, "app-server", "--listen", f"ws://127.0.0.1:{port}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=codex_subprocess_env(),
            start_new_session=True,
        )
    except OSError as exc:
        raise CodexRemoteError(str(exc)) from exc

    try:
        _wait_codex_app_server(proc, port, timeout)
        rate_limits = _read_codex_rate_limits_ws(port, timeout)
        if not rate_limits:
            raise CodexRemoteError("Codex app-server returned no rate-limit data.")
        return rate_limits
    except Exception as websocket_exc:
        if websocket_error is not None:
            raise CodexRemoteError(
                f"stdio app-server failed: {websocket_error}; websocket app-server failed: {websocket_exc}"
            ) from websocket_exc
        raise
    finally:
        if "proc" in locals():
            _terminate_process_group(proc)


def _read_codex_rate_limits_stdio(codex_cli: str, timeout: int) -> dict:
    proc = subprocess.Popen(
        [codex_cli, "app-server", "--listen", "stdio://"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=codex_subprocess_env(),
        start_new_session=True,
    )
    try:
        if proc.stdin is None or proc.stdout is None:
            raise CodexRemoteError("Codex stdio app-server pipes unavailable.")
        def send(message: dict):
            proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            proc.stdin.flush()

        for message in (
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": CODEX_GAUGE_CLIENT,
                    "capabilities": {"experimentalApi": True, "requestAttestation": False},
                },
            },
            {
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {},
            },
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "account/usage/read",
                "params": None,
            },
        ):
            send(message)

        deadline = time.monotonic() + timeout
        lines: list[str] = []
        rate_limit_results: list[dict] = []
        next_rate_limit_id = 3
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                raise CodexRemoteError("Codex stdio app-server exited: " + "".join(lines[-3:]).strip())
            ready, _, _ = select.select([proc.stdout], [], [], 0.1)
            if not ready:
                continue
            line = proc.stdout.readline()
            if not line:
                continue
            lines.append(line)
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            message_id = message.get("id")
            if message_id == 2:
                send({
                    "jsonrpc": "2.0",
                    "id": next_rate_limit_id,
                    "method": "account/rateLimits/read",
                    "params": None,
                })
                continue
            if message_id not in range(3, 3 + RATE_LIMIT_SAMPLE_COUNT):
                continue
            if "error" in message:
                raise CodexRemoteError(str(message["error"]))
            rate_limit_results.append(message.get("result") or {})
            if len(rate_limit_results) < RATE_LIMIT_SAMPLE_COUNT:
                next_rate_limit_id += 1
                send({
                    "jsonrpc": "2.0",
                    "id": next_rate_limit_id,
                    "method": "account/rateLimits/read",
                    "params": None,
                })
                continue
            return _verified_remote_rate_limits(rate_limit_results)
        raise CodexRemoteError("Codex stdio rate-limit response timed out.")
    finally:
        _terminate_process_group(proc)


def _wait_codex_app_server(proc: subprocess.Popen, port: int, timeout: int):
    deadline = time.monotonic() + timeout
    lines: list[str] = []
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise CodexRemoteError("Codex app-server exited: " + "".join(lines[-3:]).strip())
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                return
        except OSError:
            pass
        if proc.stdout:
            ready, _, _ = select.select([proc.stdout], [], [], 0)
            if ready:
                lines.append(proc.stdout.readline())
        time.sleep(0.1)
    raise CodexRemoteError("Codex app-server start timed out.")


def _select_codex_rate_limits(result: dict) -> dict:
    if not isinstance(result, dict):
        return {}

    def is_codex_bucket(key, bucket: dict) -> bool:
        key_text = str(key or "").lower()
        limit_id = str(bucket.get("limitId") or bucket.get("limit_id") or "").lower()
        limit_name = str(bucket.get("limitName") or bucket.get("limit_name") or "").lower()
        return (
            key_text == "codex"
            or key_text.startswith("codex_")
            or limit_id == "codex"
            or limit_id.startswith("codex_")
            or "codex" in limit_name
        )

    by_id = result.get("rateLimitsByLimitId") or {}
    if isinstance(by_id, dict):
        for key, bucket in by_id.items():
            if str(key).lower() == "codex" and isinstance(bucket, dict):
                return bucket
        for bucket in by_id.values():
            if isinstance(bucket, dict) and str(bucket.get("limitId") or "").lower() == "codex":
                return bucket
        for key, bucket in by_id.items():
            if isinstance(bucket, dict) and is_codex_bucket(key, bucket):
                return bucket
        if by_id:
            return {}

    rate_limits = result.get("rateLimits") or {}
    return rate_limits if isinstance(rate_limits, dict) else {}


def _normalize_remote_rate_limits(rate_limits: dict) -> dict:
    def pick(data: dict, *keys):
        for key in keys:
            if key in data and data[key] is not None:
                return data[key]
        return None

    def window(data):
        if not isinstance(data, dict):
            return None
        used = pick(data, "usedPercent", "used_percent")
        if used is None:
            return None
        return {
            "used_percent": used,
            "window_minutes": pick(data, "windowDurationMins", "window_minutes"),
            "resets_at": pick(data, "resetsAt", "resets_at"),
        }

    return {
        "limit_id": pick(rate_limits, "limitId", "limit_id"),
        "limit_name": pick(rate_limits, "limitName", "limit_name"),
        "primary": window(rate_limits.get("primary")),
        "secondary": window(rate_limits.get("secondary")),
        "credits": rate_limits.get("credits"),
        "plan_type": pick(rate_limits, "planType", "plan_type", "plan"),
        "rate_limit_reached_type": pick(
            rate_limits,
            "rateLimitReachedType",
            "rate_limit_reached_type",
        ),
    }


def _merge_remote_rate_limit_samples(
    rate_limit_samples: list[dict],
    now: float | None = None,
) -> dict:
    normalized = [
        _normalize_remote_rate_limits(sample)
        for sample in rate_limit_samples
        if isinstance(sample, dict) and sample
    ]
    if not normalized:
        return {}

    now = time.time() if now is None else now
    merged = dict(normalized[-1])
    for window_key in ("primary", "secondary"):
        windows = [
            sample.get(window_key)
            for sample in normalized
            if isinstance(sample.get(window_key), dict)
            and sample[window_key].get("used_percent") is not None
        ]
        if not windows:
            merged[window_key] = None
            continue

        reset_windows = []
        for window in windows:
            try:
                reset_epoch = float(window.get("resets_at"))
            except (TypeError, ValueError):
                continue
            if reset_epoch > now - RESET_FUTURE_GRACE_SEC:
                reset_windows.append((reset_epoch, window))

        candidates = windows
        if reset_windows:
            earliest_reset = min(epoch for epoch, _ in reset_windows)
            latest_reset = max(epoch for epoch, _ in reset_windows)
            candidates = [window for _, window in reset_windows]
            if latest_reset - earliest_reset > RATE_LIMIT_RESET_JITTER_SEC:
                candidates = [
                    window
                    for reset_epoch, window in reset_windows
                    if latest_reset - reset_epoch <= RATE_LIMIT_RESET_JITTER_SEC
                ]

        def used_percent(window: dict) -> float:
            try:
                return float(window.get("used_percent"))
            except (TypeError, ValueError):
                return -1

        merged[window_key] = dict(max(candidates, key=used_percent))
    return merged


def _verified_remote_rate_limits(results: list[dict]) -> dict:
    samples = []
    for result in results:
        rate_limits = _select_codex_rate_limits(result)
        if rate_limits:
            samples.append(rate_limits)
    if not samples:
        raise CodexRemoteError("Codex app-server returned no rate-limit data.")
    return _merge_remote_rate_limit_samples(samples)


def _rate_limits_with_plausible_resets(rate_limits: dict, now: float | None = None) -> dict:
    now = time.time() if now is None else now
    sanitized = dict(rate_limits)
    for key in ("primary", "secondary"):
        window = rate_limits.get(key)
        if not isinstance(window, dict):
            continue
        sanitized_window = dict(window)
        if sanitized_window.get("resets_at") is not None and _plausible_reset_epoch(sanitized_window, now, key) is None:
            sanitized_window["resets_at"] = None
        sanitized[key] = sanitized_window
    return sanitized


def _plausible_reset_epoch(window, now: float, window_key: str | None = None) -> float | None:
    if not isinstance(window, dict):
        return None
    resets_at = window.get("resets_at")
    try:
        reset_epoch = float(resets_at)
    except (TypeError, ValueError):
        return None
    if not reset_epoch or reset_epoch <= now:
        return None
    if reset_epoch - now > _reset_max_future_seconds(window, window_key):
        return None
    return reset_epoch


def _reset_max_future_seconds(window: dict, window_key: str | None) -> float:
    window_minutes = window.get("window_minutes")
    try:
        minutes = float(window_minutes)
    except (TypeError, ValueError):
        minutes = 0
    if minutes > 0:
        return minutes * 60 + RESET_FUTURE_GRACE_SEC
    if window_key == "primary":
        return PRIMARY_RESET_MAX_FUTURE_SEC
    return SECONDARY_RESET_MAX_FUTURE_SEC


def _read_codex_rate_limits_ws(port: int, timeout: int) -> dict:
    with socket.create_connection(("127.0.0.1", port), timeout=timeout) as sock:
        _ws_handshake(sock, port)
        _ws_send_json(sock, {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "clientInfo": CODEX_GAUGE_CLIENT,
                "capabilities": {"experimentalApi": True, "requestAttestation": False},
            },
        })
        _ws_send_json(sock, {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {},
        })
        _ws_send_json(sock, {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "account/usage/read",
            "params": None,
        })
        deadline = time.monotonic() + timeout
        rate_limit_results: list[dict] = []
        next_rate_limit_id = 3
        while time.monotonic() < deadline:
            sock.settimeout(max(0.1, deadline - time.monotonic()))
            message = _ws_recv_json(sock)
            message_id = message.get("id")
            if message_id == 2:
                _ws_send_json(sock, {
                    "jsonrpc": "2.0",
                    "id": next_rate_limit_id,
                    "method": "account/rateLimits/read",
                    "params": None,
                })
                continue
            if message_id not in range(3, 3 + RATE_LIMIT_SAMPLE_COUNT):
                continue
            if "error" in message:
                raise CodexRemoteError(str(message["error"]))
            rate_limit_results.append(message.get("result") or {})
            if len(rate_limit_results) < RATE_LIMIT_SAMPLE_COUNT:
                next_rate_limit_id += 1
                _ws_send_json(sock, {
                    "jsonrpc": "2.0",
                    "id": next_rate_limit_id,
                    "method": "account/rateLimits/read",
                    "params": None,
                })
                continue
            return _verified_remote_rate_limits(rate_limit_results)
        raise CodexRemoteError("Codex rate-limit response timed out.")


def _ws_handshake(sock: socket.socket, port: int):
    key = base64.b64encode(os.urandom(16)).decode()
    request = (
        f"GET / HTTP/1.1\r\n"
        f"Host: 127.0.0.1:{port}\r\n"
        f"Upgrade: websocket\r\n"
        f"Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        f"Sec-WebSocket-Version: 13\r\n\r\n"
    )
    sock.sendall(request.encode())
    response = b""
    while b"\r\n\r\n" not in response:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
    if b" 101 " not in response.split(b"\r\n", 1)[0]:
        raise CodexRemoteError("Codex websocket handshake failed.")


def _ws_send_json(sock: socket.socket, obj: dict):
    payload = json.dumps(obj, separators=(",", ":")).encode()
    key = os.urandom(4)
    size = len(payload)
    if size < 126:
        header = bytes([0x81, 0x80 | size])
    elif size < 65536:
        header = bytes([0x81, 0x80 | 126]) + struct.pack("!H", size)
    else:
        header = bytes([0x81, 0x80 | 127]) + struct.pack("!Q", size)
    masked = bytes(byte ^ key[index % 4] for index, byte in enumerate(payload))
    sock.sendall(header + key + masked)


def _ws_recv_json(sock: socket.socket) -> dict:
    opcode, payload = _ws_recv_frame(sock)
    if opcode == 8:
        raise CodexRemoteError("Codex websocket closed.")
    if opcode != 1:
        return {}
    return json.loads(payload.decode("utf-8"))


def _ws_recv_frame(sock: socket.socket):
    head = _recv_exact(sock, 2)
    first, second = head
    size = second & 0x7F
    if size == 126:
        size = struct.unpack("!H", _recv_exact(sock, 2))[0]
    elif size == 127:
        size = struct.unpack("!Q", _recv_exact(sock, 8))[0]
    mask = _recv_exact(sock, 4) if (second & 0x80) else b""
    payload = _recv_exact(sock, size) if size else b""
    if mask:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return first & 0x0F, payload


def _recv_exact(sock: socket.socket, size: int) -> bytes:
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise CodexRemoteError("Codex websocket ended unexpectedly.")
        data += chunk
    return data


def _round_left_from_used(used) -> int:
    try:
        return int(round(max(0, min(100, 100 - float(used)))))
    except (TypeError, ValueError):
        return 0


def _left_from_window(window: dict | None):
    if not isinstance(window, dict):
        return None
    used = window.get("used_percent", window.get("percent_used"))
    if used is None:
        return None
    return _round_left_from_used(used)


def _codex_status() -> dict:
    timestamp = datetime.datetime.now(datetime.timezone.utc)
    data_time = timestamp.isoformat()
    try:
        rate_limits = live_codex_rate_limits()
    except Exception as exc:
        return {
            "ok": False,
            "service": "Codex",
            "five_hour_left": None,
            "seven_day_left": None,
            "five_hour_reset": None,
            "seven_day_reset": None,
            "plan": None,
            "source": "live",
            "data_time": data_time,
            "error": f"Codex live usage unavailable: {exc}",
        }

    if not rate_limits:
        return {
            "ok": False,
            "service": "Codex",
            "five_hour_left": None,
            "seven_day_left": None,
            "five_hour_reset": None,
            "seven_day_reset": None,
            "plan": None,
            "source": "live",
            "data_time": data_time,
            "error": "Codex live usage unavailable: no rate-limit data.",
        }

    rate_limits = _rate_limits_with_plausible_resets(rate_limits)

    primary = rate_limits.get("primary") or {}
    secondary = rate_limits.get("secondary") or {}
    five_hour_left = _left_from_window(primary)
    seven_day_left = _left_from_window(secondary)
    if five_hour_left is None and seven_day_left is None:
        return {
            "ok": False,
            "service": "Codex",
            "five_hour_left": None,
            "seven_day_left": None,
            "five_hour_reset": primary.get("resets_at"),
            "seven_day_reset": secondary.get("resets_at"),
            "plan": rate_limits.get("plan_type") or rate_limits.get("plan") or "?",
            "source": "live",
            "data_time": data_time,
            "error": "Codex live usage unavailable: missing usage percentages.",
        }

    return {
        "ok": True,
        "service": "Codex",
        "five_hour_left": five_hour_left,
        "seven_day_left": seven_day_left,
        "five_hour_reset": primary.get("resets_at"),
        "seven_day_reset": secondary.get("resets_at"),
        "plan": rate_limits.get("plan_type") or rate_limits.get("plan") or "?",
        "source": "live",
        "data_time": data_time,
        "error": None,
    }


def _title(codex: dict) -> str:
    def pct(value):
        if value is None:
            return "--"
        return f"{max(0, min(100, int(value)))}%"

    if not codex.get("ok"):
        return "5h --  7d --"
    return f"5h {pct(codex.get('five_hour_left'))}  7d {pct(codex.get('seven_day_left'))}"


def build_status_snapshot(now: datetime.datetime | None = None) -> dict:
    now = now or datetime.datetime.now(datetime.timezone.utc)
    codex = _codex_status()
    return {
        "title": _title(codex),
        "updated_at": now.isoformat(),
        "codex": codex,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Print Codex Gauge status JSON.")
    parser.add_argument(
        "--status-json",
        action="store_true",
        help="Print Codex Gauge status JSON and exit.",
    )
    parser.parse_args(argv)

    json.dump(build_status_snapshot(), sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
