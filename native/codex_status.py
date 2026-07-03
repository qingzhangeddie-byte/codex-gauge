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


REMOTE_TIMEOUT_SEC = 5
LOCAL_SNAPSHOT_MAX_FILES = 80
LOCAL_SNAPSHOT_MAX_BYTES = 2 * 1024 * 1024
LOCAL_SNAPSHOT_MAX_AGE_SEC = 14 * 24 * 60 * 60
LOCAL_SNAPSHOT_MAX_STALENESS_SEC = 15 * 60
LAST_LIVE_CACHE_MAX_AGE_SEC = 30 * 60
PRIMARY_RESET_MAX_FUTURE_SEC = 6 * 60 * 60
SECONDARY_RESET_MAX_FUTURE_SEC = 8 * 24 * 60 * 60
RESET_FUTURE_GRACE_SEC = 60
ENV_CODEX_CLI_PATH = "CODEX_GAUGE_CODEX_CLI_PATH"
ENV_SUPPORT_DIR = "CODEX_GAUGE_SUPPORT_DIR"
ENV_NO_STORAGE = "CODEX_GAUGE_NO_STORAGE"
ENV_READ_LOCAL_SNAPSHOT = "CODEX_GAUGE_READ_LOCAL_SNAPSHOT"
LAST_LIVE_CACHE_FILE = "last-live-status.json"
CODEX_GAUGE_CLIENT = {"name": "codex-gauge", "title": "Codex Gauge", "version": "0"}


class CodexRemoteError(Exception):
    pass


def no_storage_enabled() -> bool:
    return os.environ.get(ENV_NO_STORAGE, "").strip() == "1"


def local_snapshot_fallback_enabled() -> bool:
    if not no_storage_enabled():
        return True
    return os.environ.get(ENV_READ_LOCAL_SNAPSHOT, "").strip() == "1"


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
        or "/Applications/Codex.app/Contents/Resources:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
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
            "Codex CLI not found. Open the Codex desktop app or install the Codex CLI."
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
        result = _read_codex_rate_limits_ws(port, timeout)
        rate_limits = _select_codex_rate_limits(result)
        if not rate_limits:
            raise CodexRemoteError("Codex app-server returned no rate-limit data.")
        return _normalize_remote_rate_limits(rate_limits)
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
                "method": "account/rateLimits/read",
                "params": None,
            },
        ):
            proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            proc.stdin.flush()

        deadline = time.monotonic() + timeout
        lines: list[str] = []
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
            if message.get("id") != 2:
                continue
            if "error" in message:
                raise CodexRemoteError(str(message["error"]))
            rate_limits = _select_codex_rate_limits(message.get("result") or {})
            if not rate_limits:
                raise CodexRemoteError("Codex stdio app-server returned no rate-limit data.")
            return _normalize_remote_rate_limits(rate_limits)
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


def latest_local_codex_rate_limits_snapshot(now: float | None = None) -> dict | None:
    if not local_snapshot_fallback_enabled():
        return None
    sessions_dir = pathlib.Path.home() / ".codex" / "sessions"
    if not sessions_dir.is_dir():
        return None

    now = time.time() if now is None else now
    candidates = []
    for path in sessions_dir.rglob("*.jsonl"):
        try:
            stat = path.stat()
        except OSError:
            continue
        if now - stat.st_mtime > LOCAL_SNAPSHOT_MAX_AGE_SEC:
            continue
        candidates.append((stat.st_mtime, path))

    for _, path in sorted(candidates, reverse=True)[:LOCAL_SNAPSHOT_MAX_FILES]:
        snapshot = _scan_codex_session_tail(path, now=now)
        if snapshot:
            snapshot["_source"] = "local_snapshot"
            return snapshot
    return None


def _scan_codex_session_tail(path: pathlib.Path, now: float | None = None) -> dict | None:
    now = time.time() if now is None else now
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            if size > LOCAL_SNAPSHOT_MAX_BYTES:
                handle.seek(size - LOCAL_SNAPSHOT_MAX_BYTES)
                handle.readline()
            raw = handle.read(LOCAL_SNAPSHOT_MAX_BYTES)
    except OSError:
        return None

    for line in reversed(raw.decode("utf-8", errors="ignore").splitlines()):
        if '"rate_limits"' not in line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
        rate_limits = event.get("rate_limits") or payload.get("rate_limits")
        if not _is_codex_rate_limit_snapshot(rate_limits):
            continue
        normalized = _normalize_remote_rate_limits(rate_limits)
        snapshot = _local_snapshot_with_fresh_windows(normalized)
        if snapshot:
            captured_at = _event_timestamp(event)
            if captured_at and _event_timestamp_is_recent(captured_at, now):
                snapshot["_captured_at"] = captured_at
                return snapshot
    return None


def _local_snapshot_with_fresh_windows(rate_limits: dict) -> dict | None:
    fresh = _rate_limits_with_plausible_resets(rate_limits)
    fresh_window_count = 0
    now = time.time()
    for key in ("primary", "secondary"):
        window = rate_limits.get(key)
        if _window_has_future_reset(window, now, key):
            fresh_window_count += 1
        else:
            fresh[key] = None
    if fresh_window_count == 0:
        return None
    return fresh


def _has_future_reset_window(rate_limits: dict) -> bool:
    now = time.time()
    return any(_window_has_future_reset(rate_limits.get(key), now, key) for key in ("primary", "secondary"))


def _window_has_future_reset(window, now: float, window_key: str | None = None) -> bool:
    return _plausible_reset_epoch(window, now, window_key) is not None


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


def _event_timestamp(event: dict) -> str | None:
    timestamp = event.get("timestamp") if isinstance(event, dict) else None
    if not isinstance(timestamp, str) or not timestamp.strip():
        return None
    return timestamp


def _event_timestamp_is_recent(timestamp: str, now: float) -> bool:
    parsed = _parse_event_timestamp(timestamp)
    if parsed is None:
        return False
    if parsed > now + 60:
        return False
    return now - parsed <= LOCAL_SNAPSHOT_MAX_STALENESS_SEC


def _parse_event_timestamp(timestamp: str) -> float | None:
    normalized = timestamp.strip()
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"
    try:
        parsed = datetime.datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=datetime.timezone.utc)
    return parsed.timestamp()


def _last_live_cache_path() -> pathlib.Path:
    configured = os.environ.get(ENV_SUPPORT_DIR, "").strip()
    if configured:
        return pathlib.Path(configured).expanduser() / LAST_LIVE_CACHE_FILE
    return pathlib.Path.home() / "Library" / "Application Support" / "CodexGauge" / LAST_LIVE_CACHE_FILE


def _write_last_live_rate_limits_cache(rate_limits: dict, captured_at: str) -> None:
    if no_storage_enabled():
        return
    if not rate_limits:
        return
    cache_path = _last_live_cache_path()
    payload = {
        "captured_at": captured_at,
        "rate_limits": rate_limits,
    }
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    except OSError:
        return


def latest_last_live_rate_limits_cache(now: float | None = None) -> dict | None:
    if no_storage_enabled():
        return None
    now = time.time() if now is None else now
    try:
        payload = json.loads(_last_live_cache_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None

    captured_at = payload.get("captured_at")
    if not isinstance(captured_at, str) or not _last_live_timestamp_is_usable(captured_at, now):
        return None

    rate_limits = payload.get("rate_limits")
    if not isinstance(rate_limits, dict):
        return None
    fresh = _local_snapshot_with_fresh_windows(rate_limits)
    if not fresh:
        return None
    fresh["_source"] = "last_live"
    fresh["_captured_at"] = captured_at
    return fresh


def _last_live_timestamp_is_usable(timestamp: str, now: float) -> bool:
    parsed = _parse_event_timestamp(timestamp)
    if parsed is None:
        return False
    if parsed > now + 60:
        return False
    return now - parsed <= LAST_LIVE_CACHE_MAX_AGE_SEC


def _is_codex_rate_limit_snapshot(rate_limits) -> bool:
    if not isinstance(rate_limits, dict):
        return False
    limit_id = str(rate_limits.get("limit_id") or rate_limits.get("limitId") or "").lower()
    return limit_id == "codex"


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
            "id": 2,
            "method": "account/rateLimits/read",
            "params": None,
        })

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            sock.settimeout(max(0.1, deadline - time.monotonic()))
            message = _ws_recv_json(sock)
            if message.get("id") == 2:
                if "error" in message:
                    raise CodexRemoteError(str(message["error"]))
                return message.get("result") or {}
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
    source = "live"
    data_time = timestamp.isoformat()
    live_error = None
    try:
        rate_limits = live_codex_rate_limits()
    except Exception as exc:
        live_error = exc
        rate_limits = latest_last_live_rate_limits_cache()
        if not rate_limits:
            rate_limits = latest_local_codex_rate_limits_snapshot()
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
                "data_time": timestamp.isoformat(),
                "error": f"Codex live usage unavailable: {exc}",
            }
        source = rate_limits.pop("_source", "local_snapshot")
        data_time = rate_limits.pop("_captured_at", data_time)
    else:
        if rate_limits:
            rate_limits = _rate_limits_with_plausible_resets(rate_limits)
            _write_last_live_rate_limits_cache(rate_limits, data_time)

    if not rate_limits:
        rate_limits = latest_last_live_rate_limits_cache() or latest_local_codex_rate_limits_snapshot()
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
                "data_time": timestamp.isoformat(),
                "error": "Codex live usage unavailable: no rate-limit data.",
            }
        source = rate_limits.pop("_source", "local_snapshot")
        data_time = rate_limits.pop("_captured_at", data_time)

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
            "source": source,
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
        "source": source,
        "data_time": data_time,
        "error": f"Codex live usage unavailable; showing last live value: {live_error}" if source == "last_live" and live_error else None,
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
