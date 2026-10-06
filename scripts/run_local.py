"""Run the API and Flutter website on localhost; Ctrl+C stops owned child processes."""

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from _workspace import ROOT, backend_python, config, flutter_executable, public_origin


def port(value: str) -> int:
    number = int(value)
    if not 1 <= number <= 65535:
        raise argparse.ArgumentTypeError("Port must be between 1 and 65535.")
    return number


def check_port_available(number: int) -> None:
    with socket.socket() as probe:
        try:
            probe.bind(("127.0.0.1", number))
        except OSError:
            raise ValueError(
                f"Local port {number} is already in use; choose another port."
            ) from None


def stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
        except ProcessLookupError:
            return
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()


def spawn(
    command: list[str | Path], cwd: Path, environment: dict[str, str]
) -> subprocess.Popen:
    if os.name == "nt":
        return subprocess.Popen(
            [str(value) for value in command],
            cwd=cwd,
            env=environment,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
            | subprocess.CREATE_NO_WINDOW,
        )
    return subprocess.Popen(
        [str(value) for value in command],
        cwd=cwd,
        env=environment,
        start_new_session=True,
    )


def wait_for_api(process: subprocess.Popen, url: str) -> None:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise ValueError("Local backend exited before readiness.")
        try:
            with urllib.request.urlopen(url + "/v1/health", timeout=1) as response:
                if json.load(response).get("status") == "ready":
                    return
        except (OSError, ValueError, urllib.error.URLError):
            pass
        time.sleep(0.25)
    raise ValueError("Local backend did not become ready within 30 seconds.")


def main() -> int:
    defaults = config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scope", choices=["all", "backend", "frontend"], default="all"
    )
    parser.add_argument("--backend-port", type=port, default=defaults["backend_port"])
    parser.add_argument("--web-port", type=port, default=defaults["web_port"])
    parser.add_argument(
        "--backend-url", help="Optional existing backend origin for frontend-only runs"
    )
    args = parser.parse_args()
    processes = []
    try:
        if args.backend_port == args.web_port and args.scope == "all":
            raise ValueError("Backend and frontend ports must differ.")
        if args.backend_url and args.scope != "frontend":
            raise ValueError("--backend-url applies only to --scope frontend.")
        backend_url = public_origin(
            args.backend_url or f"http://127.0.0.1:{args.backend_port}"
        )
        flutter = flutter_executable() if args.scope in {"all", "frontend"} else None
        if args.scope in {"all", "backend"}:
            check_port_available(args.backend_port)
        if args.scope in {"all", "frontend"}:
            check_port_available(args.web_port)
        if args.scope in {"all", "backend"}:
            python = backend_python()
            if not python.is_file() or not (ROOT / "backend/.env").is_file():
                raise ValueError(
                    "Run scripts/setup.py --scope backend before starting the API."
                )
            environment = dict(os.environ)
            environment["CORS_ORIGINS"] = json.dumps(
                [
                    f"http://127.0.0.1:{args.web_port}",
                    f"http://localhost:{args.web_port}",
                ]
            )
            if (ROOT / "backend/storage/runtime/india/catalogue.sqlite3").is_file():
                environment["CATALOGUE_DIRECTORY"] = "storage/runtime/india"
                environment["CATALOGUE_REQUIRE_RECEIPT"] = "false"
            command = [
                python,
                "-m",
                "uvicorn",
                "app.main:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(args.backend_port),
            ]
            backend = spawn(command, ROOT / "backend", environment)
            processes.append(backend)
            wait_for_api(backend, backend_url)
            print(f"Backend ready: {backend_url}/docs", flush=True)
        if flutter is not None:
            command = [
                flutter,
                "run",
                "-d",
                "web-server",
                "--web-hostname",
                "127.0.0.1",
                "--web-port",
                str(args.web_port),
                f"--dart-define=BACKEND_BASE_URL={backend_url}",
            ]
            processes.append(spawn(command, ROOT / "frontend", dict(os.environ)))
            print(
                f"Frontend starting: http://127.0.0.1:{args.web_port} (browser opens manually).",
                flush=True,
            )
        print(
            "Press Ctrl+C to stop both owned process trees. Local .env is unchanged.",
            flush=True,
        )
        while all(process.poll() is None for process in processes):
            time.sleep(0.5)
        raise ValueError("A local service exited; stopping remaining owned processes.")
    except KeyboardInterrupt:
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        message = (
            f"tool exit {error.returncode}"
            if isinstance(error, subprocess.CalledProcessError)
            else str(error)
        )
        print(f"Local run stopped: {message}", file=sys.stderr)
        return 1
    finally:
        for process in reversed(processes):
            stop_process(process)


if __name__ == "__main__":
    raise SystemExit(main())
