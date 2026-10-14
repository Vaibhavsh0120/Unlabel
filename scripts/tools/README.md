# Local preview tools

Keep downloaded executables in `scripts/tools/caddy/` (ignored). On Windows use
`caddy_windows_amd64.exe`; on macOS/Linux use `caddy`, or install it on PATH.
Download from [official Caddy](https://caddyserver.com/download). The launcher
does not download or install software, change firewall rules, or enable billing.

## Three launcher modes

Run `python scripts/run_local.py` for a menu, or select a mode:

| Command | Connection |
| --- | --- |
| `python scripts/run_local.py --mode local` | PC-local Flutter HTTP preview to PC-local backend |
| `python scripts/run_local.py --mode production` | PC-local Flutter to the fixed production API through a bounded loopback proxy |
| `python scripts/run_local.py --mode lan` | HTTPS Flutter and local API at one Wi-Fi address through Caddy |

Windows wrapper: `./scripts/run-local.ps1 -Mode lan`. Use `--lan-ip 192.168.1.20`
(`-LanIp`) if VPNs/multiple adapters select the wrong interface. HTTPS defaults
to port 8443; `--https-port` (`-HttpsPort`) changes it. Ports already in use cause
an error; the launcher never kills unrelated processes. Ctrl+C stops its children.

LAN mode exposes only the selected private interface over HTTPS. The backend
stays on loopback; `/v1/*` is proxied to it without removing that prefix. Flutter
uses the same HTTPS origin, avoiding HTTP mixed content. Other modes remain
loopback-only. Production mode uses real hosted data and starts no local backend.

## Trust HTTPS on your test devices

Caddy generates a development CA on first run and keeps it stable under ignored
`output/local-network/data/`. The launcher prints its public `root.crt` path.
Copy **only root.crt** to devices you own and trust that root for development:

- Windows: import into the current user's Trusted Root Certification Authorities.
- iPhone/iPad: install the certificate profile, then enable it in Settings >
  General > About > Certificate Trust Settings.
- Android: install the CA certificate in the device's security settings; browser
  trust and work-profile policies may differ.

Open the printed `https://IP:8443` address on the same Wi-Fi. If Windows Firewall
blocks it, allow Caddy only on your private network. No router port forwarding is
needed. Camera/secure-context APIs require a trusted certificate; clicking through
a certificate warning is not equivalent. Firebase Google sign-in may still require
an authorized hostname and provider configuration; LAN HTTPS alone cannot grant it.

Never share `root.key`, intermediate keys, or the entire runtime directory. The
launcher deliberately does not install certificates automatically. Remove the
trusted root when no longer using this development CA. Deleting the runtime data
generates a new CA and requires trusting the new public certificate.

Generated `Caddyfile`, CA material and runtime configuration stay under
`output/local-network/`. Verification captures stay under `output/auth-reference/`.
Neither folder nor the executable is published to GitHub or bundled in the app.
