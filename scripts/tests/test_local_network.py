"""Synthetic local HTTPS boundaries; no network, certificates or processes."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dev._local_network import lan_address, prepare_https, wait_for_https


class LocalNetworkTest(unittest.TestCase):
    def test_only_private_ipv4_is_accepted(self):
        for value in (
            "127.0.0.1",
            "0.0.0.0",
            "8.8.8.8",
            "localhost",
            "::1",
            "192.168.1.1\n}",
        ):
            with self.subTest(value=value), self.assertRaises(ValueError):
                lan_address(value)
        for value in ("192.168.1.20", "10.0.0.4", "172.16.0.2"):
            self.assertEqual(lan_address(value), value)

    def test_https_keeps_the_api_prefix_and_local_generated_material(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config, environment, certificate = prepare_https(
                root, "192.168.1.20", 8443, 8000
            )
            text = config.read_text()
            self.assertIn("handle /v1/*", text)
            self.assertNotIn("handle_path", text)
            self.assertIn("reverse_proxy 127.0.0.1:8000", text)
            self.assertIn("bind 192.168.1.20", text)
            self.assertIn("admin off", text)
            self.assertIn("skip_install_trust", text)
            self.assertIn("tls internal", text)
            self.assertTrue(config.is_relative_to(root / "output/local-network"))
            self.assertTrue(certificate.is_relative_to(root / "output/local-network"))
            self.assertEqual(
                environment["XDG_DATA_HOME"], str(root / "output/local-network/data")
            )

    def test_occupied_ports_do_not_terminate_other_processes(self):
        import run_local

        with (
            patch.object(sys, "argv", ["run_local.py", "--mode", "production"]),
            patch.object(run_local, "flutter_executable", return_value=Path("flutter")),
            patch.object(
                run_local, "check_port_available", side_effect=ValueError("Port in use")
            ),
            patch.object(run_local, "spawn") as spawn,
            patch.object(run_local, "stop_process") as stop,
        ):
            self.assertEqual(run_local.main(), 1)
            spawn.assert_not_called()
            stop.assert_not_called()

    def test_caddy_failure_is_reported_before_claiming_ready(self):
        class Exited:
            def poll(self):
                return 1

        with self.assertRaisesRegex(ValueError, "exited"):
            wait_for_https(Exited(), "https://192.168.1.20:8443", Path("missing.crt"))
