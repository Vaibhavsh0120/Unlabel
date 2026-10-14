"""Private-LAN HTTPS configuration; downloaded tools and CA keys stay local."""

import ipaddress
import os
import shutil
import socket
import ssl
import time
import urllib.request
from pathlib import Path


def lan_address(value: str | None = None) -> str:
    if value is None:
        # UDP connect selects the outbound interface without sending a packet.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            try:
                probe.connect(("192.0.2.1", 9))
                value = probe.getsockname()[0]
            except OSError:
                raise ValueError(
                    "Choose your Wi-Fi IPv4 address with --lan-ip."
                ) from None
    try:
        address = ipaddress.IPv4Address(value)
    except ipaddress.AddressValueError:
        raise ValueError(
            "--lan-ip must be a private Wi-Fi/Ethernet IPv4 address."
        ) from None
    if not any(
        address in ipaddress.IPv4Network(network)
        for network in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
    ):
        raise ValueError("--lan-ip must be a private Wi-Fi/Ethernet IPv4 address.")
    return str(address)


def caddy_executable(root: Path) -> Path:
    name = "caddy_windows_amd64.exe" if os.name == "nt" else "caddy"
    local = root / "scripts/tools/caddy" / name
    if local.is_file():
        return local
    installed = shutil.which("caddy")
    if installed:
        return Path(installed)
    raise ValueError(
        "Install Caddy or place it in scripts/tools/caddy; see scripts/tools/README.md."
    )


def prepare_https(root: Path, address: str, https_port: int, backend_port: int):
    """One HTTPS origin serves public Flutter files and proxies the local API."""
    address = lan_address(address)
    if not all(
        type(port) is int and 1 <= port <= 65535 for port in (https_port, backend_port)
    ):
        raise ValueError("HTTPS/backend ports must be between 1 and 65535.")
    runtime = root / "output/local-network"
    runtime.mkdir(parents=True, exist_ok=True)
    public = (root / "frontend/build/web").resolve().as_posix()
    if any(character in public for character in ('"', "\n", "\r")):
        raise ValueError("Workspace path cannot contain Caddyfile quoting characters.")
    config = runtime / "Caddyfile"
    config.write_text(
        f'''{{
    admin off
    auto_https disable_redirects
    skip_install_trust
}}
https://{address}:{https_port} {{
    bind {address}
    tls internal
    header Cache-Control "no-store"
    header X-Content-Type-Options "nosniff"
    handle /v1/* {{
        reverse_proxy 127.0.0.1:{backend_port}
    }}
    handle {{
        root * "{public}"
        try_files {{path}} /index.html
        file_server
    }}
}}
''',
        encoding="utf-8",
    )
    environment = dict(os.environ)
    environment["XDG_DATA_HOME"] = str(runtime / "data")
    environment["XDG_CONFIG_HOME"] = str(runtime / "config")
    certificate = runtime / "data/caddy/pki/authorities/local/root.crt"
    return config, environment, certificate


def wait_for_https(process, origin: str, certificate: Path) -> None:
    """Verify local TLS with this CA without weakening system/browser trust."""
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise ValueError("Local HTTPS server exited before readiness.")
        if certificate.is_file():
            try:
                context = ssl.create_default_context(cafile=str(certificate))
                opener = urllib.request.build_opener(
                    urllib.request.ProxyHandler({}),
                    urllib.request.HTTPSHandler(context=context),
                )
                with opener.open(origin + "/index.html", timeout=1) as response:
                    if response.status == 200:
                        return
            except OSError:
                pass
        time.sleep(0.2)
    raise ValueError(
        "Local HTTPS did not become ready; check the selected LAN IP and Caddy output."
    )
