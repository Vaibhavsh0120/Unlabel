"""Choose Local or Production preview; Ctrl+C stops only owned child processes."""

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

from _preview_server import PRODUCTION_ORIGIN, serve_web
from _workspace import (
    ROOT,
    backend_python,
    config,
    flutter_executable,
    frontend_version,
    public_origin,
)


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


def choose_mode() -> str:
    if not sys.stdin.isatty():
        raise ValueError(
            "Select --mode local or --mode production for a noninteractive run."
        )
    print(
        "1. Local: frontend and local backend\n2. Production: frontend and hosted API",
        flush=True,
    )
    while True:
        choice = input("Choose 1 or 2: ").strip().lower()
        if choice in {"1", "local"}:
            return "local"
        if choice in {"2", "production"}:
            return "production"
        print("Choose Local (1) or Production (2); there is no default.", flush=True)


def wait_for_web(process: subprocess.Popen, url: str) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise ValueError("Frontend preview exited before readiness.")
        try:
            with urllib.request.urlopen(url + "/index.html", timeout=1) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.URLError):
            pass
        time.sleep(0.1)
    raise ValueError("Frontend preview did not become ready within 10 seconds.")


def main() -> int:
    defaults = config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["local", "production"])
    parser.add_argument("--scope", choices=["all", "backend", "frontend"])
    parser.add_argument("--serve-web", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--backend-port", type=port, default=defaults["backend_port"])
    parser.add_argument("--web-port", type=port, default=defaults["web_port"])
    parser.add_argument(
        "--backend-url", help="Optional existing backend origin for frontend-only runs"
    )
    args = parser.parse_args()
    processes = []
    try:
        if args.serve_web:
            if args.mode is None:
                raise ValueError("The preview server requires an explicit mode.")
            return serve_web(ROOT / "frontend/build/web", args.web_port, args.mode)
        if args.mode and args.scope:
            raise ValueError("Use --mode or the legacy --scope selection, not both.")
        mode = args.mode or ("local" if args.scope else choose_mode())
        scope = args.scope or ("all" if mode == "local" else "frontend")
        if args.backend_port == args.web_port and scope == "all":
            raise ValueError("Backend and frontend ports must differ.")
        if args.backend_url and scope != "frontend":
            raise ValueError("--backend-url applies only to --scope frontend.")
        if args.backend_url and public_origin(args.backend_url) == PRODUCTION_ORIGIN:
            mode = "production"
        elif mode == "production" and args.backend_url:
            raise ValueError("Production mode uses only the fixed hosted Unlabel API.")
        web_url = f"http://127.0.0.1:{args.web_port}"
        backend_url = public_origin(
            web_url
            if mode == "production"
            else args.backend_url or f"http://127.0.0.1:{args.backend_port}"
        )
        flutter = flutter_executable() if scope in {"all", "frontend"} else None
        print(
            f"Mode: {mode.title()}; API target: {PRODUCTION_ORIGIN if mode == 'production' else backend_url}",
            flush=True,
        )
        if mode == "production":
            print(
                "Production data is live. This mode starts no local backend.",
                flush=True,
            )
        if scope in {"all", "backend"}:
            check_port_available(args.backend_port)
        if scope in {"all", "frontend"}:
            check_port_available(args.web_port)
        if scope in {"all", "backend"}:
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
            app_version, build_number = frontend_version()
            command = [
                flutter,
                "build",
                "web",
                "--debug",
                "--no-pub",
                f"--dart-define=BACKEND_BASE_URL={backend_url}",
                f"--dart-define=APP_VERSION={app_version}",
                f"--dart-define=BUILD_NUMBER={build_number}",
            ]
            build = spawn(command, ROOT / "frontend", dict(os.environ))
            processes.append(build)
            while build.poll() is None:
                time.sleep(0.2)
            if build.returncode != 0:
                raise ValueError("Flutter preview build failed.")
            processes.remove(build)
            preview = spawn(
                [
                    sys.executable,
                    ROOT / "scripts/run_local.py",
                    "--serve-web",
                    "--mode",
                    mode,
                    "--web-port",
                    str(args.web_port),
                ],
                ROOT,
                dict(os.environ),
            )
            processes.append(preview)
            wait_for_web(preview, web_url)
            print(f"Frontend ready: {web_url} (open the browser manually).", flush=True)
        print(
            "Press Ctrl+C to stop owned process trees. Local .env is unchanged.",
            flush=True,
        )
        while all(process.poll() is None for process in processes):
            time.sleep(0.5)
        raise ValueError("A local service exited; stopping remaining owned processes.")
    except (KeyboardInterrupt, EOFError):
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
