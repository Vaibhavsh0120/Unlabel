"""Release guardrails run without platform SDKs, credentials or network access."""

import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from mobile_release import (
    GitHub,
    JsonObject,
    refresh_source,
    response_list,
    response_object,
    validate_inputs,
    verify_asset,
)
from package_ios import validate_info
from prepare_android_ci import android_versions


class ReleaseGuardTests(unittest.TestCase):
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
