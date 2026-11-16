"""Release guardrails run without platform SDKs, credentials or network access."""

import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))

from backend_target import validate_backend_target
from frontend_release_gate import previous_frontend_manifest, version_changed
from mobile_release import (
    GitHub,
    JsonObject,
    promote_frontend_release,
    public_assets,
    refresh_source,
    response_list,
    response_object,
    validate_inputs,
    verify_asset,
)
from package_ios import validate_info
from prepare_android_ci import android_versions


class ReleaseGuardTests(unittest.TestCase):
    def test_latest_is_reserved_for_complete_published_frontend_apps(self):
        class FakeGitHub:
            root = "https://api.github.com/repos/owner/repo"

            def __init__(self):
                self.calls = []

            def api(self, url, data=None, method=None):
                self.calls.append((url, data, method))
                return {"tag_name": "frontend-v0.11.1+16"}

        good = {
            "tag_name": "frontend-v0.11.1+16",
            "draft": False,
            "url": "https://api.github.com/repos/owner/repo/releases/1",
            "assets": [{"name": n} for n in ["app.apk", "app.ipa", "apps.json"]],
        }
        github = FakeGitHub()
        with (
            patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}),
            self.assertRaises(ValueError),
        ):
            promote_frontend_release(github, good)
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
            promote_frontend_release(github, good)
        self.assertEqual(
            github.calls[0][1], {"prerelease": False, "make_latest": "true"}
        )
        for bad in [
            {**good, "draft": True},
            {**good, "tag_name": "backend-v0.15.0"},
            {**good, "assets": [{"name": "apps.json"}]},
        ]:
            with (
                patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}),
                self.assertRaises(ValueError),
            ):
                promote_frontend_release(github, bad)

    def test_dependency_or_copy_edits_do_not_trigger_mobile_release(self):
        old = "name: unlabel\nversion: 0.8.0+12\ndependencies: {}\n"
        self.assertFalse(version_changed(old, ("0.8.0", "12")))
        self.assertTrue(version_changed(old, ("0.9.0", "13")))
        self.assertTrue(version_changed(old, ("0.8.0", "13")))
        for current in [("0.9.0", "12"), ("0.7.0", "13"), ("0.8.0", "11")]:
            with self.assertRaises(ValueError):
                version_changed(old, current)

    def test_release_gate_fetches_an_unavailable_push_base(self):
        success = Mock(returncode=0, stdout="version: 0.8.0+12\n")
        failure = Mock(returncode=1, stdout="")
        with patch(
            "frontend_release_gate.subprocess.run",
            side_effect=[failure, success, success],
        ) as run:
            self.assertEqual(
                previous_frontend_manifest("a" * 40), "version: 0.8.0+12\n"
            )
        self.assertEqual(
            run.call_args_list[1].args[0][:4], ["git", "fetch", "--no-tags", "origin"]
        )

    def test_release_gate_skips_when_push_base_cannot_be_verified(self):
        failure = Mock(returncode=1, stdout="")
        with (
            patch(
                "frontend_release_gate.subprocess.run",
                side_effect=[failure, failure, failure],
            ),
            patch("frontend_release_gate.sys.stderr", new_callable=io.StringIO) as error,
        ):
            self.assertIsNone(previous_frontend_manifest("b" * 40))
        self.assertIn("skipping automatic mobile release", error.getvalue())

    def test_public_release_excludes_build_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in [
                "app.apk",
                "app.ipa",
                "apps.json",
                "build-manifest.json",
                "SHA256SUMS.txt",
                "ios-toolchain.json",
            ]:
                (root / name).write_text("synthetic")
            self.assertEqual(
                set(public_assets(root, ["app.apk", "app.ipa"])),
                {"app.apk", "app.ipa", "apps.json"},
            )

    def test_api_response_shapes_are_required_before_mutating_releases(self):
        self.assertEqual(response_object({"id": 1}), {"id": 1})
        self.assertEqual(response_list([{"id": 1}]), [{"id": 1}])
        for bad in (None, [], "invalid"):
            with self.assertRaises(TypeError):
                response_object(bad)
        for bad in (None, {}, [None]):
            with self.assertRaises(TypeError):
                response_list(bad)

    def setUp(self):
        self.environment = {
            "RELEASE_VERSION": "0.7.0",
            "BUILD_NUMBER": "11",
            "BACKEND_BASE_URL": "https://unlabel-api.vercel.app",
            "UNLABEL_SELF_HOSTED_AUTH": "false",
            "PUBLISH_RELEASE": "true",
            "GITHUB_REPOSITORY": "owner/repo",
            "GH_TOKEN": "synthetic-test-token",
        }

    def test_release_inputs_reject_credentials_and_shell_artifacts(self):
        with patch.dict(os.environ, self.environment):
            validate_inputs()
            for url in (
                "https://user:password@example.com",
                "https://example.com/?token=value",
                "https://example.com/\n",
                "http://example.com",
                "https://example.com/api",
            ):
                os.environ["BACKEND_BASE_URL"] = url
                with self.assertRaises(ValueError):
                    validate_inputs()

    def test_self_hosted_auth_requires_ready_dependencies_not_cutover_flag(self):
        def response(payload):
            result = Mock()
            result.__enter__ = Mock(return_value=result)
            result.__exit__ = Mock(return_value=False)
            result.status = 200
            result.read.return_value = payload
            return result

        with patch(
            "backend_target.urllib.request.urlopen",
            return_value=response(
                b'{"status":"ready","dependencies":["postgresql","mongodb","redis","identity"]}'
            ),
        ) as open_url:
            validate_backend_target("https://selfhost.example.test", True)
        open_url.assert_called_once()

    def test_self_hosted_auth_requires_all_dependencies_to_be_ready(self):
        result = Mock()
        result.__enter__ = Mock(return_value=result)
        result.__exit__ = Mock(return_value=False)
        result.status = 200
        result.read.return_value = (
            b'{"status":"ready","dependencies":["postgresql","mongodb","redis"]}'
        )
        with (
            patch("backend_target.urllib.request.urlopen", return_value=result),
            self.assertRaisesRegex(ValueError, "dependencies are not ready"),
        ):
            validate_backend_target("https://selfhost.example.test", True)

    def test_legacy_backend_does_not_require_a_readiness_probe(self):
        with patch("backend_target.urllib.request.urlopen") as open_url:
            validate_backend_target("https://unlabel-api.vercel.app", False)
        open_url.assert_not_called()

    def test_self_hosted_auth_rejects_non_https_and_invalid_flag(self):
        for origin in ("http://selfhost.example.test", "https://example.test/api"):
            with self.assertRaises(ValueError):
                validate_backend_target(origin, True)
        with self.assertRaisesRegex(ValueError, "requires self-hosted auth"):
            validate_backend_target("https://unlabel.duckdns.org", False)
        with (
            patch.dict(
                os.environ,
                {**self.environment, "UNLABEL_SELF_HOSTED_AUTH": "yes"},
            ),
            self.assertRaisesRegex(ValueError, "must be boolean"),
        ):
            validate_inputs()

    def test_noncanonical_version_or_android_build_is_rejected(self):
        for variable, value in (
            ("RELEASE_VERSION", "0.7"),
            ("BUILD_NUMBER", "0"),
            ("BUILD_NUMBER", "2100000001"),
            ("BUILD_NUMBER", "11\n"),
        ):
            with (
                patch.dict(os.environ, {**self.environment, variable: value}),
                self.assertRaises(ValueError),
            ):
                validate_inputs()

    def test_existing_tag_is_never_overwritten(self):
        with patch.dict(os.environ, self.environment):
            github = GitHub()
            with patch.object(
                github, "api", return_value={"ref": "tags/frontend-v0.7.0+11"}
            ) as api:
                with self.assertRaises(ValueError):
                    github.unused("frontend-v0.7.0+11")
                self.assertEqual(api.call_count, 1)

    def test_existing_draft_without_tag_is_also_rejected(self):
        with patch.dict(os.environ, self.environment):
            github = GitHub()
            with (
                patch.object(
                    github,
                    "api",
                    side_effect=[None, [{"tag_name": "frontend-v0.7.0+11"}]],
                ),
                self.assertRaises(ValueError),
            ):
                github.unused("frontend-v0.7.0+11")

    def test_partial_upload_or_checksum_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            asset = Path(directory) / "app.ipa"
            asset.write_bytes(b"synthetic-archive")
            good = {"state": "uploaded", "size": asset.stat().st_size}
            verify_asset(good, asset)
            for bad in (
                {**good, "state": "new"},
                {**good, "size": 0},
                {**good, "digest": "sha256:incorrect"},
            ):
                with self.assertRaises(ValueError):
                    verify_asset(bad, asset)

    def test_ios_packaging_rejects_simulator_and_different_identity(self):
        info = {
            "CFBundleShortVersionString": "0.7.0",
            "CFBundleVersion": "11",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "CFBundleIdentifier": "in.unlabel.unlabel",
            "CFBundleExecutable": "Runner",
        }
        validate_info(info, "0.7.0", "11")
        for key, value in (
            ("CFBundleSupportedPlatforms", ["iPhoneSimulator"]),
            ("CFBundleIdentifier", "other.app"),
            ("CFBundleVersion", "12"),
            ("CFBundleExecutable", "../Runner"),
        ):
            with self.assertRaises(ValueError):
                validate_info({**info, key: value}, "0.7.0", "11")

    def test_sdk_requirements_come_from_flutter_instead_of_version_literals(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            extension = (
                root
                / "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
            )
            extension.parent.mkdir(parents=True)
            extension.write_text(
                'val compileSdkVersion: Int = 36\nval ndkVersion: String = "28.2.13676358"'
            )
            self.assertEqual(android_versions(root), ("36", "28.2.13676358"))
            extension.write_text("unsupported SDK format")
            with self.assertRaises(ValueError):
                android_versions(root)

    def test_source_replacement_uploads_before_removing_the_previous_feed(self):
        self._source_replacement(fail_rename=False)

    def test_source_replacement_restores_previous_feed_when_rename_fails(self):
        self._source_replacement(fail_rename=True)

    def _source_replacement(self, *, fail_rename):
        old = {
            "name": "apps.json",
            "url": "old",
            "browser_download_url": "https://example.com/apps.json",
        }

        class FakeGitHub:
            root = "https://api.github.com/repos/owner/repo"

            def __init__(self):
                self.assets: dict[str, JsonObject] = {"old": old.copy()}
                self.calls: list[str | tuple[str | None, str]] = []

            def release(self, tag: str) -> JsonObject | None:
                return {"draft": False, "assets": list(self.assets.values())}

            def upload(
                self, release: JsonObject, path: Path, name: str | None = None
            ) -> JsonObject:
                self.calls.append("upload")
                if self.assets["old"]["name"] != "apps.json":
                    raise AssertionError(
                        "Old source must remain available while uploading."
                    )
                self.assets["staged"] = {
                    "url": "staged",
                    "name": name,
                    "state": "uploaded",
                    "size": path.stat().st_size,
                    "browser_download_url": "https://example.com/apps.json",
                }
                return self.assets["staged"].copy()

            def api(
                self,
                url: str,
                data: JsonObject | bytes | None = None,
                method: str | None = None,
                *,
                missing: bool = False,
                content_type: str = "application/json",
            ) -> object:
                self.calls.append((method, url))
                if method == "PATCH":
                    if not isinstance(data, dict):
                        raise ValueError("Synthetic PATCH requires object data.")
                    if fail_rename and url == "staged":
                        raise ValueError("Synthetic rename failure")
                    self.assets[url].update(data)
                elif method == "DELETE":
                    self.assets.pop(url)
                    return None
                return self.assets.get(url, {}).copy()

        github = FakeGitHub()
        with tempfile.TemporaryDirectory() as directory:
            ipa = Path(directory) / "app.ipa"
            ipa.write_bytes(b"synthetic IPA replaced by inspector mock")
            published = {
                "assets": [
                    {
                        "name": "app.ipa",
                        "browser_download_url": "https://example.com/app.ipa",
                    }
                ]
            }
            with (
                patch.dict(
                    os.environ,
                    {**self.environment, "GITHUB_RUN_ID": "123", "SOURCE_SHA": "abc"},
                ),
                patch(
                    "urllib.request.urlopen", return_value=io.BytesIO(b'{"apps": []}')
                ),
                patch("ios_source.create_source", return_value={"apps": []}),
            ):
                if fail_rename:
                    with self.assertRaises(ValueError):
                        refresh_source(github, ipa, published, "2026-10-12")
                    self.assertEqual(github.assets["old"]["name"], "apps.json")
                    self.assertNotIn(("DELETE", "old"), github.calls)
                else:
                    self.assertEqual(
                        refresh_source(github, ipa, published, "2026-10-12"),
                        "https://example.com/apps.json",
                    )
                    self.assertNotIn("old", github.assets)
                    self.assertEqual(github.assets["staged"]["name"], "apps.json")
                self.assertEqual(github.calls[0], "upload")


if __name__ == "__main__":
    unittest.main()
