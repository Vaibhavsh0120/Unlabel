"""Loopback-only Flutter preview and a bounded proxy to the fixed production API."""

import http.client
import json
import re
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import cast
from urllib.parse import unquote, urlsplit

PRODUCTION_HOST = "unlabel-api.vercel.app"
PRODUCTION_ORIGIN = f"https://{PRODUCTION_HOST}"
BARCODE = r"(?:[0-9]{8}|[0-9]{12,14})"
UUID = r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
ENTRY_ID = r"[0-9a-f]{64}"
REJECTED_BODY_LIMIT = 512 * 1024 + 1
REJECTED_BODY_TIMEOUT = 0.2
GET_ROUTES = (
    r"/v1/(?:health|meta|catalogue|catalogue/search|claims/rules|ingredients/glossary)",
    rf"/v1/catalogue/products/{BARCODE}(?:/facts)?",
    rf"/v1/products/{BARCODE}(?:/nutrition|/resolved|/report)?",
    r"/v1/evidence/[a-z][a-z0-9-]{0,63}",
    rf"/v1/community/contributions/{UUID}",
    rf"/v1/community/products/{BARCODE}",
    r"/v1/researched/products/search",
    rf"/v1/researched/products/{ENTRY_ID}",
    rf"/v1/researched/products/by-barcode/{BARCODE}",
    r"/v1/account/sync",
    r"/v1/ai/active",
)
POST_ROUTES = (
    r"/v1/(?:nutrition/normalize|claims/check|community/contributions|reports/check|reports/compare|account/sync)",
    r"/v1/ai/extract",
)


def allowed_route(method: str, path: str) -> bool:
    patterns = (
        GET_ROUTES if method == "GET" else POST_ROUTES if method == "POST" else ()
    )
    return any(re.fullmatch(pattern, path) for pattern in patterns)


def web_handler(directory: Path, mode: str):
    root = directory.resolve()
    capacity = threading.BoundedSemaphore(6)

    class PreviewHandler(SimpleHTTPRequestHandler):
        """Never record requests, query strings, headers, credentials or payloads."""

        def __init__(self, *args, **kwargs):
            self._cors_origin = None
            self._body_consumed = 0
            super().__init__(*args, directory=str(root), **kwargs)

        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def log_message(self, format, *args):
            pass

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            if self._cors_origin:
                self.send_header("Access-Control-Allow-Origin", self._cors_origin)
                self.send_header("Vary", "Origin")
            super().end_headers()

        def fail(self, status: int, code: str):
            body = json.dumps({"error": code}).encode("utf-8")
            self.close_connection = True
            self.discard_rejected_body()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)

        def discard_rejected_body(self):
            """Bounded cleanup avoids resetting a socket with a small unread body."""
            lengths = self.headers.get_all("Content-Length", [])
            if (
                self.headers.get("Transfer-Encoding")
                or self.headers.get("Expect")
                or len(lengths) != 1
                or re.fullmatch(r"[0-9]{1,10}", lengths[0]) is None
            ):
                return
            remaining = min(
                max(0, int(lengths[0]) - self._body_consumed), REJECTED_BODY_LIMIT
            )
            if not remaining:
                return
            deadline = time.monotonic() + REJECTED_BODY_TIMEOUT
            try:
                while remaining:
                    timeout = deadline - time.monotonic()
                    if timeout <= 0:
                        break
                    self.connection.settimeout(timeout)
                    chunk = self.rfile.read1(min(65536, remaining))
                    if not chunk:
                        break
                    self._body_consumed += len(chunk)
                    remaining -= len(chunk)
            except OSError:
                pass
            finally:
                self.connection.settimeout(15)

        def valid_request(self) -> bool:
            port = cast(ThreadingHTTPServer, self.server).server_port
            if self.headers.get("Host") not in {
                f"127.0.0.1:{port}",
                f"localhost:{port}",
            }:
                self.fail(403, "local_host_required")
                return False
            origin = self.headers.get("Origin")
            if origin and origin not in {
                f"http://127.0.0.1:{port}",
                f"http://localhost:{port}",
            }:
                self.fail(403, "local_origin_required")
                return False
            self._cors_origin = origin
            try:
                parsed = urlsplit(self.path)
            except ValueError:
                self.fail(400, "invalid_preview_path")
                return False
            if (
                not self.path.isascii()
                or len(self.path) > 4096
                or any(ord(char) < 32 for char in self.path)
                or parsed.scheme
                or parsed.netloc
                or parsed.fragment
                or not self.path.startswith("/")
                or "//" in parsed.path
                or "%" in parsed.path
                or "\\" in parsed.path
            ):
                self.fail(400, "invalid_preview_path")
                return False
            return True

        def send_head(self):
            parts = unquote(urlsplit(self.path).path).replace("\\", "/").split("/")
            if any(part in {".", ".."} for part in parts):
                self.fail(404, "preview_file_missing")
                return None
            target = Path(self.translate_path(self.path)).resolve()
            if target.is_dir():
                target = (target / "index.html").resolve()
            if not target.is_relative_to(root) or not target.is_file():
                self.fail(404, "preview_file_missing")
                return None
            return super().send_head()

        def do_GET(self):
            if self.valid_request():
                if urlsplit(self.path).path.startswith("/v1/"):
                    self.proxy()
                else:
                    super().do_GET()

        def do_HEAD(self):
            if self.valid_request():
                if urlsplit(self.path).path.startswith("/v1/"):
                    self.fail(405, "preview_method_not_allowed")
                else:
                    super().do_HEAD()

        def do_POST(self):
            if self.valid_request():
                self.proxy()

        def do_OPTIONS(self):
            if not self.valid_request():
                return
            method = self.headers.get("Access-Control-Request-Method", "")
            path = urlsplit(self.path).path
            headers = {
                value.strip().lower()
                for value in self.headers.get(
                    "Access-Control-Request-Headers", ""
                ).split(",")
                if value.strip()
            }
            if (
                mode != "production"
                or not allowed_route(method, path)
                or not headers.issubset({"authorization", "content-type"})
            ):
                self.fail(403, "preview_preflight_not_allowed")
                return
            self.send_response(204)
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header(
                "Access-Control-Allow-Headers", "Authorization, Content-Type"
            )
            self.send_header("Content-Length", "0")
            self.end_headers()

        def proxy(self):
            path = urlsplit(self.path).path
            if mode != "production" or not allowed_route(self.command, path):
                self.fail(404, "preview_api_route_not_allowed")
                return
            lengths = self.headers.get_all("Content-Length", [])
            if (
                self.headers.get("Transfer-Encoding")
                or self.headers.get("Expect")
                or len(lengths) > 1
                or (lengths and re.fullmatch(r"[0-9]{1,10}", lengths[0]) is None)
            ):
                self.fail(400, "invalid_preview_framing")
                return
            size = int(lengths[0]) if lengths else 0
            limit = {
                "/v1/account/sync": 512 * 1024,
                "/v1/reports/compare": 64 * 1024,
                "/v1/ai/extract": 4 * 1024 * 1024,
            }.get(path, 32 * 1024)
            if size > limit:
                self.fail(413, "preview_request_too_large")
                return
            if self.command == "GET" and size:
                self.fail(400, "preview_get_body_not_allowed")
                return
            if self.command == "POST" and (
                not lengths
                or self.headers.get("Content-Type", "").split(";", 1)[0].lower()
                != "application/json"
            ):
                self.fail(415, "preview_json_required")
                return
            auth = self.headers.get_all("Authorization", [])
            if len(auth) > 1 or (
                auth
                and (
                    len(auth[0]) > 8199
                    or re.fullmatch(r"Bearer [A-Za-z0-9._~-]+", auth[0]) is None
                )
            ):
                self.fail(400, "invalid_preview_authorization")
                return
            if not capacity.acquire(blocking=False):
                self.fail(503, "preview_api_busy")
                return
            connection = None
            try:
                body = self.rfile.read(size) if size else None
                self._body_consumed = len(body) if body is not None else 0
                if body is not None and len(body) != size:
                    self.fail(400, "incomplete_preview_body")
                    return
                headers = {"Accept": "application/json", "Accept-Encoding": "identity"}
                if self.command == "POST":
                    headers["Content-Type"] = "application/json"
                if auth:
                    headers["Authorization"] = auth[0]
                connection = http.client.HTTPSConnection(PRODUCTION_HOST, timeout=15)
                deadline = time.monotonic() + 15
                connection.request(self.command, self.path, body=body, headers=headers)
                response = connection.getresponse()
                declared = response.getheader("Content-Length")
                response_limit = (
                    512 * 1024 if path == "/v1/account/sync" else 2 * 1024 * 1024
                )
                if (
                    300 <= response.status < 400
                    or response.getheader("Content-Encoding", "identity") != "identity"
                    or (
                        declared is not None
                        and (not declared.isdigit() or int(declared) > response_limit)
                    )
                ):
                    self.fail(502, "invalid_preview_api_response")
                    return
                payload = bytearray()
                while True:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise TimeoutError
                    if connection.sock is not None:
                        connection.sock.settimeout(remaining)
                    chunk = response.read1(
                        min(65536, response_limit + 1 - len(payload))
                    )
                    if not chunk:
                        break
                    payload.extend(chunk)
                    if len(payload) > response_limit:
                        self.fail(502, "preview_api_response_too_large")
                        return
                if declared is not None and len(payload) != int(declared):
                    self.fail(502, "incomplete_preview_api_response")
                    return
                self.send_response(response.status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                retry_after = response.getheader("Retry-After", "")
                if re.fullmatch(r"[0-9]{1,6}", retry_after):
                    self.send_header("Retry-After", retry_after)
                self.end_headers()
                self.wfile.write(payload)
            except (OSError, ValueError, http.client.HTTPException):
                self.fail(502, "preview_api_unavailable")
            finally:
                if connection is not None:
                    connection.close()
                capacity.release()

    return PreviewHandler


def serve_web(directory: Path, port: int, mode: str) -> int:
    if not (directory / "index.html").is_file():
        raise ValueError("Build the Flutter web preview before serving it.")
    with ThreadingHTTPServer(
        ("127.0.0.1", port), web_handler(directory, mode)
    ) as server:
        server.daemon_threads = True
        try:
            server.serve_forever(poll_interval=0.25)
        except KeyboardInterrupt:
            return 0
    return 0
