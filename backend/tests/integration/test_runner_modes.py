"""Launcher ownership and the production preview's credential/transport boundary."""

import http.client
import importlib.util
import io
import json
import sys
import threading
from contextlib import contextmanager
from email.message import Message
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

from app.main import create_app

ROOT = Path(__file__).resolve().parents[3]


def module(name, monkeypatch):
    monkeypatch.syspath_prepend(str(ROOT / "scripts"))
    spec = importlib.util.spec_from_file_location(f"runner_{name}", ROOT / (f"scripts/dev/{name}.py" if name.startswith("_") else f"scripts/{name}.py"))
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


@contextmanager
def preview(preview_module, tmp_path, mode="production"):
    (tmp_path / "index.html").write_text("<html>Preview fixture</html>")
    server = ThreadingHTTPServer(("127.0.0.1", 0), preview_module.web_handler(tmp_path, mode))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server.server_port
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def request(port, method, path, body=None, headers=None):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
    try:
        connection.request(method, path, body, headers or {})
        response = connection.getresponse()
        return response.status, dict(response.getheaders()), response.read()
    finally:
        connection.close()


def test_model_fetch_is_inline_binary_with_unchanged_compressed_bytes(tmp_path, monkeypatch):
    handler = module('_preview_server', monkeypatch)
    model = tmp_path / 'ocr/lang/eng.traineddata.gz'
    model.parent.mkdir(parents=True)
    data = b'\x1f\x8bowned-compressed-model-fixture'
    model.write_bytes(data)
    with preview(handler, tmp_path) as port:
        status, headers, body = request(port, 'GET', '/ocr/lang/eng.traineddata.gz')
    headers = {key.lower(): value for key, value in headers.items()}
    assert status == 200
    assert headers['content-type'] == 'application/octet-stream'
    assert headers['content-disposition'] == 'inline'
    assert headers['x-content-type-options'] == 'nosniff'
    assert 'content-encoding' not in headers
    assert body == data


class UpstreamResponse:
    def __init__(self, payload=b'{"status":"ready"}', status=200, headers=None):
        self.payload = payload
        self.status = status
        self.headers = headers or {}

    def getheader(self, name, default=None):
        return self.headers.get(name, default)

    def read1(self, size):
        result, self.payload = self.payload[:size], self.payload[size:]
        return result


def upstream(monkeypatch, preview_module, response=None, error=None):
    calls = []

    class Connection:
        sock = None

        def __init__(self, host, timeout):
            calls.append(("connect", host, timeout))

        def request(self, method, path, body, headers):
            calls.append((method, path, body, headers))
            if error:
                raise error

        def getresponse(self):
            return response or UpstreamResponse()

        def close(self):
            calls.append(("closed",))

    monkeypatch.setattr(preview_module.http.client, "HTTPSConnection", Connection)
    return calls


def test_selection_has_no_silent_default(monkeypatch, capsys):
    runner = module("run_local", monkeypatch)
    monkeypatch.setattr(runner.sys.stdin, "isatty", lambda: True)
    choices = iter(["", "wrong", "2"])
    monkeypatch.setattr("builtins.input", lambda _: next(choices))
    assert runner.choose_mode() == "production"
    assert "there is no default" in capsys.readouterr().out
    monkeypatch.setattr(runner.sys.stdin, "isatty", lambda: False)
    with pytest.raises(ValueError, match="noninteractive"):
        runner.choose_mode()


@pytest.mark.parametrize(
    ("argv", "backend_expected", "proxy_mode"),
    [
        (["--mode", "production"], False, "production"),
        (
            ["--scope", "frontend", "--backend-url", "https://unlabel-api.vercel.app"],
            False,
            "production",
        ),
        (["--mode", "local"], True, "local"),
        (["--mode", "lan", "--lan-ip", "192.168.1.20"], True, "lan"),
        (["--scope", "frontend", "--backend-url", "http://127.0.0.1:8123"], False, "local"),
    ],
)
def test_modes_launch_only_owned_services(
    tmp_path, monkeypatch, argv, backend_expected, proxy_mode
):
    runner = module("run_local", monkeypatch)
    (tmp_path / "backend/.venv").mkdir(parents=True)
    (tmp_path / "backend/.env").write_bytes(b"existing settings remain private")
    python = tmp_path / "backend/.venv/python"
    python.touch()
    calls, stopped, checked_ports = [], [], []

    class Process:
        def __init__(self, command):
            self.command = command
            self.returncode = 0 if "build" in command else None

        def poll(self):
            return self.returncode

    def spawn(command, cwd, environment):
        process = Process([str(value) for value in command])
        calls.append((process, cwd, environment))
        return process

    def interrupt(_):
        raise KeyboardInterrupt

    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(runner, "config", lambda: {"backend_port": 8000, "web_port": 7357})
    monkeypatch.setattr(runner, "backend_python", lambda: python)
    monkeypatch.setattr(runner, "flutter_executable", lambda: Path("flutter"))
    monkeypatch.setattr(runner, "caddy_executable", lambda _: Path("caddy"))
    monkeypatch.setattr(runner, "spawn", spawn)
    monkeypatch.setattr(runner, "stop_process", stopped.append)
    monkeypatch.setattr(runner, "wait_for_api", lambda *args: None)
    monkeypatch.setattr(runner, "wait_for_web", lambda *args: None)
    monkeypatch.setattr(runner, "wait_for_https", lambda *args: None)
    monkeypatch.setattr(runner, "check_port_available", checked_ports.append)
    monkeypatch.setattr(runner.time, "sleep", interrupt)
    monkeypatch.setattr(sys, "argv", ["run_local.py", *argv])
    assert runner.main() == 0
    commands = [call[0].command for call in calls]
    assert any("uvicorn" in command for command in commands) is backend_expected
    assert (8000 in checked_ports) is backend_expected
    build = next(command for command in commands if "build" in command)
    assert "--debug" in build and "--no-pub" in build
    assert next(call[1] for call in calls if "build" in call[0].command) == tmp_path / "frontend"
    # Flutter reads this directory's pubspec and embeds the reserved version
    # constants itself. A launcher must not inject a second, stale identity.
    assert not any(
        argument.startswith(("--build-name", "--build-number", "--dart-define=APP_VERSION", "--dart-define=BUILD_NUMBER"))
        for argument in build
    )
    url = (
        "https://192.168.1.20:8443" if proxy_mode == "lan" else "http://127.0.0.1:7357"
        if proxy_mode in {"production", "lan"}
        else ("http://127.0.0.1:8000" if backend_expected else "http://127.0.0.1:8123")
    )
    assert f"--dart-define=BACKEND_BASE_URL={url}" in build
    if proxy_mode == "lan":
        assert commands[-1][0] == "caddy" and "run" in commands[-1]
        config = (tmp_path / "output/local-network/Caddyfile").read_text()
        assert "https://192.168.1.20:8443" in config
        assert "reverse_proxy 127.0.0.1:8000" in config
        assert "skip_install_trust" in config
    else:
        assert commands[-1][-3:] == [proxy_mode, "--web-port", "7357"]
    if backend_expected:
        backend = next(command for command in commands if "uvicorn" in command)
        assert backend[backend.index("--host") + 1] == "127.0.0.1"
    assert stopped == list(reversed([call[0] for call in calls if "build" not in call[0].command]))
    assert (tmp_path / "backend/.env").read_bytes() == b"existing settings remain private"


def test_proxy_covers_exact_current_operations(monkeypatch):
    handler = module("_preview_server", monkeypatch)
    paths = create_app().openapi()["paths"]
    for path, operations in paths.items():
        if path == "/v1/ai/control/activate":
            # Machine control goes directly to the backend, outside app preview.
            assert not handler.allowed_route("POST", path)
            continue
        concrete = path.replace("{barcode}", "12345678").replace(
            "{source_id}", "fssai-ac-2022-schedule-i"
        )
        concrete = concrete.replace("{submission_id}", "01234567-89ab-cdef-0123-456789abcdef")
        concrete = concrete.replace("{entry_id}", "a" * 64)
        for method in operations:
            assert handler.allowed_route(method.upper(), concrete), (method, path)
    assert not handler.allowed_route("POST", "/v1/account/admin")
    assert not handler.allowed_route("GET", "/v1/products/123")
    assert handler.allowed_route("DELETE", "/v1/account/sync")
    assert not handler.allowed_route("DELETE", "/v1/account/admin")
    assert not handler.allowed_route("DELETE", "/v1/products/12345678")
    assert not handler.allowed_route("GET", "/v1/researched/products/" + "a" * 63)
    assert not handler.allowed_route("GET", "/v1/researched/products/" + "g" * 64)
    assert not handler.allowed_route("POST", "/v1/researched/products/search")
    assert not handler.allowed_route("GET", "/v1/researched/products/by-barcode/123")


def test_proxy_preserves_comparison_body_budget(tmp_path, monkeypatch):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    body = b" " * (64 * 1024)
    content_type = {"Content-Type": "application/json"}
    with preview(handler, tmp_path) as port:
        status, headers, _ = request(port, "POST", "/v1/reports/compare", body, content_type)
        assert status == 200
        assert headers["Cache-Control"] == "no-store"
        assert calls[1][0:3] == ("POST", "/v1/reports/compare", body)
        before = [call for call in calls if call[0] != "closed"]
        assert (
            request(
                port,
                "POST",
                "/v1/reports/compare",
                b"{}",
                {**content_type, "Content-Length": str(64 * 1024 + 1)},
            )[0]
            == 413
        )
        assert [call for call in calls if call[0] != "closed"] == before


def test_proxy_forwards_only_bearer_to_fixed_https_target(tmp_path, monkeypatch, capsys):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(
        monkeypatch, handler, UpstreamResponse(headers={"Set-Cookie": "private=fixture"})
    )
    with preview(handler, tmp_path) as port:
        status, headers, body = request(
            port,
            "GET",
            "/v1/account/sync?private=fixture",
            headers={
                "Authorization": "Bearer synthetic.token",
                "Cookie": "private=fixture",
                "Origin": f"http://127.0.0.1:{port}",
            },
        )
    assert status == 200 and json.loads(body)["status"] == "ready"
    assert calls[0] == ("connect", "unlabel-api.vercel.app", 15)
    assert calls[1][3] == {
        "Accept": "application/json",
        "Accept-Encoding": "identity",
        "Authorization": "Bearer synthetic.token",
    }
    assert "Set-Cookie" not in headers and headers["Cache-Control"] == "no-store"
    assert calls[-1] == ("closed",)
    output = capsys.readouterr()
    assert (
        "fixture" not in output.out + output.err
        and "synthetic.token" not in output.out + output.err
    )


def test_proxy_forwards_bodyless_owner_delete_and_allows_local_preflight(tmp_path, monkeypatch):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler, UpstreamResponse(payload=b'{"status":"deleted"}'))
    with preview(handler, tmp_path) as port:
        origin = f"http://127.0.0.1:{port}"
        status, headers, body = request(port, "OPTIONS", "/v1/account/sync", headers={
            "Origin": origin,
            "Access-Control-Request-Method": "DELETE",
            "Access-Control-Request-Headers": "Authorization",
        })
        assert status == 204 and body == b""
        assert "DELETE" in headers["Access-Control-Allow-Methods"]
        assert headers["Access-Control-Allow-Origin"] == origin
        assert calls == []
        status, headers, body = request(port, "DELETE", "/v1/account/sync", headers={
            "Authorization": "Bearer synthetic.token", "Origin": origin,
            "Cookie": "private=fixture",
        })
    assert status == 200 and json.loads(body) == {"status": "deleted"}
    assert headers["Cache-Control"] == "no-store"
    assert headers["Access-Control-Allow-Origin"] == origin
    assert calls[0] == ("connect", "unlabel-api.vercel.app", 15)
    assert calls[1] == ("DELETE", "/v1/account/sync", None, {
        "Accept": "application/json", "Accept-Encoding": "identity",
        "Authorization": "Bearer synthetic.token",
    })
    assert calls[-1] == ("closed",)


def test_proxy_rejects_delete_payloads_and_other_routes_before_upstream(tmp_path, monkeypatch):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    with preview(handler, tmp_path) as port:
        status, headers, body = request(port, "DELETE", "/v1/account/sync", body=b"{}")
        assert status == 400
        assert json.loads(body) == {"error": "preview_delete_body_not_allowed"}
        assert headers["Cache-Control"] == "no-store"
        assert request(port, "DELETE", "/v1/products/12345678")[0] == 404
        assert request(port, "OPTIONS", "/v1/products/12345678", headers={
            "Origin": f"http://127.0.0.1:{port}",
            "Access-Control-Request-Method": "DELETE",
        })[0] == 403
    assert calls == []


@pytest.mark.parametrize(
    ("path", "headers", "status"),
    [
        ("/v1/meta", {"Origin": "https://untrusted.example"}, 403),
        ("/v1/meta", {"Host": "untrusted.example"}, 403),
        ("/v1/admin", {}, 404),
        ("/v1/products/%2fmeta", {}, 400),
        ("/v1/meta", {"Authorization": "Basic fixture"}, 400),
    ],
)
def test_proxy_rejects_untrusted_requests_before_upstream(
    tmp_path, monkeypatch, path, headers, status
):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    with preview(handler, tmp_path) as port:
        assert request(port, "GET", path, headers=headers)[0] == status
    assert not calls


def test_proxy_bounds_body_and_preserves_account_sync_allowance(tmp_path, monkeypatch):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    with preview(handler, tmp_path) as port:
        assert (
            request(
                port,
                "POST",
                "/v1/reports/check",
                body=b"{}",
                headers={"Content-Type": "text/plain"},
            )[0]
            == 415
        )
        assert (
            request(
                port,
                "POST",
                "/v1/reports/check",
                body=b"x" * (32 * 1024 + 1),
                headers={"Content-Type": "application/json"},
            )[0]
            == 413
        )
        assert not calls
        snapshot = b"x" * (384 * 1024 + 1024)
        assert (
            request(
                port,
                "POST",
                "/v1/account/sync",
                body=snapshot,
                headers={"Content-Type": "application/json"},
            )[0]
            == 200
        )
        assert calls[1][2] == snapshot
        assert (
            request(
                port,
                "POST",
                "/v1/account/sync",
                body=b"{}",
                headers={"Content-Type": "application/json", "Content-Length": str(512 * 1024 + 1)},
            )[0]
            == 413
        )
    assert len([call for call in calls if call[0] == "connect"]) == 1
    assert len([call for call in calls if call[0] == "POST"]) == 1


@pytest.mark.parametrize(
    ("path", "size"),
    [
        ("/v1/reports/check", 32 * 1024 + 1),
        ("/v1/reports/compare", 64 * 1024 + 1),
        ("/v1/account/sync", 512 * 1024 + 1),
    ],
)
def test_proxy_delivers_body_rejection_without_upstream(tmp_path, monkeypatch, path, size):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    with preview(handler, tmp_path) as port:
        status, headers, body = request(
            port, "POST", path, b"x" * size, {"Content-Type": "application/json"}
        )
    assert status == 413 and json.loads(body) == {"error": "preview_request_too_large"}
    assert headers["Cache-Control"] == "no-store"
    assert not calls


def rejected_body_fixture(handler, headers, body, consumed=0):
    result = object.__new__(handler.web_handler(Path("."), "production"))
    result.headers = Message()
    for name, value in headers:
        result.headers[name] = value
    result.rfile = io.BytesIO(body)
    result._body_consumed = consumed
    timeouts = []

    class Connection:
        def settimeout(self, timeout):
            timeouts.append(timeout)

    result.connection = Connection()
    return result, timeouts


def test_rejected_body_cleanup_is_byte_bounded_and_skips_consumed_bytes(monkeypatch):
    handler = module("_preview_server", monkeypatch)
    body = b"x" * (handler.REJECTED_BODY_LIMIT + 100)
    instance, timeouts = rejected_body_fixture(handler, [("Content-Length", str(len(body)))], body)
    instance.discard_rejected_body()
    assert instance.rfile.tell() == handler.REJECTED_BODY_LIMIT
    assert instance._body_consumed == handler.REJECTED_BODY_LIMIT
    assert all(0 < timeout <= handler.REJECTED_BODY_TIMEOUT for timeout in timeouts[:-1])
    assert timeouts[-1] == 15
    instance, timeouts = rejected_body_fixture(handler, [("Content-Length", "2")], b"", consumed=2)
    instance.discard_rejected_body()
    assert instance.rfile.tell() == 0 and not timeouts


def test_rejected_body_cleanup_has_total_deadline(monkeypatch):
    handler = module("_preview_server", monkeypatch)
    instance, timeouts = rejected_body_fixture(handler, [("Content-Length", "70000")], b"x" * 70000)
    instants = iter([1.0, 1.01, 1.0 + handler.REJECTED_BODY_TIMEOUT + 0.01])
    monkeypatch.setattr(handler.time, "monotonic", lambda: next(instants))
    instance.discard_rejected_body()
    assert instance.rfile.tell() == 65536
    assert 0 < timeouts[0] <= handler.REJECTED_BODY_TIMEOUT and timeouts[-1] == 15


def test_rejected_body_timeout_never_rounds_above_configured_cap(monkeypatch):
    handler = module("_preview_server", monkeypatch)
    instance, timeouts = rejected_body_fixture(handler, [("Content-Length", "2")], b"{}")
    # At this timestamp, float(instant + 0.2) - instant is slightly above 0.2.
    monkeypatch.setattr(handler.time, "monotonic", lambda: 100_000_000.0)
    instance.discard_rejected_body()
    assert instance.rfile.tell() == 2
    assert timeouts == [handler.REJECTED_BODY_TIMEOUT, 15]


@pytest.mark.parametrize(
    "headers",
    [
        [],
        [("Content-Length", "-1")],
        [("Content-Length", "2"), ("Content-Length", "2")],
        [("Content-Length", "2"), ("Transfer-Encoding", "chunked")],
        [("Content-Length", "2"), ("Expect", "100-continue")],
    ],
)
def test_rejected_body_cleanup_never_interprets_ambiguous_framing(monkeypatch, headers):
    handler = module("_preview_server", monkeypatch)
    instance, timeouts = rejected_body_fixture(handler, headers, b"{}")
    instance.discard_rejected_body()
    assert instance.rfile.tell() == 0 and not timeouts


@pytest.mark.parametrize(
    "response",
    [
        UpstreamResponse(status=302, headers={"Location": "https://other.example"}),
        UpstreamResponse(headers={"Content-Length": str(2 * 1024 * 1024 + 1)}),
        UpstreamResponse(payload=b"x" * (2 * 1024 * 1024 + 1)),
        UpstreamResponse(headers={"Content-Length": "100"}),
    ],
)
def test_proxy_rejects_redirects_oversized_or_truncated_response(tmp_path, monkeypatch, response):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler, response)
    with preview(handler, tmp_path) as port:
        status, headers, _ = request(port, "GET", "/v1/meta")
    assert status == 502 and "Location" not in headers
    assert len([call for call in calls if call[0] == "connect"]) == 1
    assert calls[-1] == ("closed",)


def test_proxy_error_does_not_expose_provider_error_or_token(tmp_path, monkeypatch, capsys):
    handler = module("_preview_server", monkeypatch)
    upstream(monkeypatch, handler, error=OSError("fixture-token private provider detail"))
    with preview(handler, tmp_path) as port:
        status, _, body = request(port, "GET", "/v1/meta")
    assert status == 502 and body == b'{"error": "preview_api_unavailable"}'
    output = capsys.readouterr()
    assert "fixture-token" not in output.out + output.err


def test_local_preview_has_no_proxy_or_directory_listing(tmp_path, monkeypatch):
    handler = module("_preview_server", monkeypatch)
    calls = upstream(monkeypatch, handler)
    (tmp_path / "assets").mkdir()
    with preview(handler, tmp_path, "local") as port:
        assert request(port, "GET", "/")[0] == 200
        assert request(port, "GET", "/assets/")[0] == 404
        assert request(port, "GET", "/../private")[0] == 404
        assert request(port, "GET", "/v1/meta")[0] == 404
    assert not calls
