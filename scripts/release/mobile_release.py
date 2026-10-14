"""Publish verified frontend mobile assets and refresh the stable iOS source."""

import argparse
import datetime
import hashlib
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Any, Protocol

SOURCE_TAG = "ios-source"
SOURCE_ASSET = "apps.json"

JsonObject = dict[str, Any]


def response_object(value: object) -> JsonObject:
    if not isinstance(value, dict):
        raise TypeError("GitHub returned an invalid JSON object response.")
    return value


def response_list(value: object) -> list[JsonObject]:
    if not isinstance(value, list):
        raise TypeError("GitHub returned an invalid JSON list response.")
    return [response_object(item) for item in value]


class ReleaseClient(Protocol):
    root: str

    def api(
        self,
        url: str,
        data: JsonObject | bytes | None = None,
        method: str | None = None,
        *,
        missing: bool = False,
        content_type: str = "application/json",
    ) -> object: ...

    def release(self, tag: str) -> JsonObject | None: ...

    def upload(
        self, release: JsonObject, path: Path, name: str | None = None
    ) -> JsonObject: ...


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_inputs() -> None:
    from urllib.parse import urlsplit

    version, build = os.environ["RELEASE_VERSION"], os.environ["BUILD_NUMBER"]
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Frontend version must have three SemVer numbers.")
    if not re.fullmatch(r"[1-9][0-9]{0,9}", build) or int(build) > 2100000000:
        raise ValueError("Build number must be a positive Android-compatible integer.")
    url = os.environ["BACKEND_BASE_URL"]
    parsed = urlsplit(url)
    if (
        len(url) > 500
        or any(c.isspace() for c in url)
        or parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in ("", "/")
    ):
        raise ValueError(
            "Backend URL must be a public HTTPS origin without credentials or a path."
        )
    if os.environ["PUBLISH_RELEASE"] not in ("true", "false"):
        raise ValueError("publish_release must be boolean.")


class GitHub:
    def __init__(self) -> None:
        self.root = f"{os.environ.get('GH_API_URL', 'https://api.github.com')}/repos/{os.environ['GITHUB_REPOSITORY']}"
        self.headers = {
            "Authorization": f"Bearer {os.environ['GH_TOKEN']}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
        }

    def api(
        self,
        url: str,
        data: JsonObject | bytes | None = None,
        method: str | None = None,
        *,
        missing: bool = False,
        content_type: str = "application/json",
    ) -> object:
        if isinstance(data, dict):
            data = json.dumps(data).encode()
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={**self.headers, "Content-Type": content_type},
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.load(response) if response.status != 204 else None
        except urllib.error.HTTPError as error:
            if missing and error.code == 404:
                return None
            raise

    def release(self, tag: str) -> JsonObject | None:
        result = self.api(
            f"{self.root}/releases/tags/{urllib.parse.quote(tag, safe='')}",
            missing=True,
        )
        return response_object(result) if result is not None else None

    def unused(self, tag: str) -> None:
        ref = urllib.parse.quote(tag, safe="")
        if self.api(f"{self.root}/git/ref/tags/{ref}", missing=True) is not None:
            raise ValueError(
                "Release tag already exists; existing releases/assets cannot be overwritten."
            )
        page = 1
        while True:
            releases = response_list(
                self.api(f"{self.root}/releases?per_page=100&page={page}")
            )
            if any(item["tag_name"] == tag for item in releases):
                raise ValueError(
                    "A release/draft already exists for this version; review it manually."
                )
            if len(releases) < 100:
                break
            page += 1

    def upload(
        self, release: JsonObject, path: Path, name: str | None = None
    ) -> JsonObject:
        upload = release["upload_url"].split("{")[0]
        asset = response_object(
            self.api(
                f"{upload}?{urllib.parse.urlencode({'name': name or path.name})}",
                path.read_bytes(),
                "POST",
                content_type="application/octet-stream",
            )
        )
        verify_asset(asset, path)
        return asset


def verify_asset(asset: JsonObject, path: Path) -> None:
    if asset.get("state") != "uploaded" or asset.get("size") != path.stat().st_size:
        raise ValueError(f"Remote upload verification failed for {path.name}.")
    digest = asset.get("digest")
    if digest and digest != f"sha256:{sha256(path)}":
        raise ValueError(f"Remote checksum mismatch for {path.name}.")


def verify_archives(out: Path, version: str, build: str) -> list[str]:
    names = [
        f"unlabel-{version}+{build}-android-demo.apk",
        f"unlabel-{version}+{build}-ios-unsigned.ipa",
    ]
    for name, member in zip(
        names, ["AndroidManifest.xml", "Payload/Runner.app/Info.plist"], strict=True
    ):
        path = out / name
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f"Missing required mobile asset: {name}.")
        with zipfile.ZipFile(path) as archive:
            if member not in archive.namelist() or archive.testzip() is not None:
                raise ValueError(f"Invalid archive structure: {name}.")
    from ios_source import inspect_ipa

    info = inspect_ipa(out / names[1])
    if info["version"] != version or info["build_number"] != build:
        raise ValueError("IPA metadata does not match the frontend version.")
    return names


def refresh_source(
    github: ReleaseClient, ipa: Path, published: JsonObject, timestamp: str
) -> str:
    from ios_source import create_source

    repo = os.environ["GITHUB_REPOSITORY"]
    existing_release = github.release(SOURCE_TAG)
    existing_asset = None
    existing_source = None
    if existing_release:
        existing_asset = next(
            (a for a in existing_release["assets"] if a["name"] == SOURCE_ASSET), None
        )
        if existing_asset:
            with urllib.request.urlopen(
                existing_asset["browser_download_url"], timeout=60
            ) as response:
                maximum = 1024 * 1024
                headers = getattr(response, "headers", {})
                if int(headers.get("Content-Length", "0")) > maximum:
                    raise ValueError(
                        "Existing iOS source exceeds the bounded JSON size."
                    )
                source_bytes = response.read(maximum + 1)
                if len(source_bytes) > maximum:
                    raise ValueError(
                        "Existing iOS source exceeds the bounded JSON size."
                    )
                existing_source = json.loads(source_bytes)
    ipa_asset = next(a for a in published["assets"] if a["name"] == ipa.name)
    source = create_source(
        ipa,
        ipa_asset["browser_download_url"],
        date=timestamp,
        icon_url=f"https://raw.githubusercontent.com/{repo}/main/frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png",
        existing=existing_source,
    )
    local_source = ipa.parent / SOURCE_ASSET
    local_source.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    if not existing_release:
        existing_release = response_object(
            github.api(
                f"{github.root}/releases",
                {
                    "tag_name": SOURCE_TAG,
                    "target_commitish": os.environ["SOURCE_SHA"],
                    "name": "iOS source — LiveContainer",
                    "draft": False,
                    "prerelease": True,
                    "make_latest": "false",
                    "body": "Stable AltStore-style source for verified Unlabel iPhoneOS release assets. Add the apps.json URL to LiveContainer Sources. The host provides signing; device behavior remains a separate check.",
                },
                "POST",
            )
        )
    if existing_release.get("draft"):
        raise ValueError(
            "The stable iOS source release is a draft; review it before replacement."
        )
    # Upload and verify first. Preserve the old feed until the replacement bytes exist.
    staged_name = f"apps-{os.environ['GITHUB_RUN_ID']}.json"
    staged = github.upload(existing_release, local_source, staged_name)
    if existing_asset:
        previous_name = f"apps-previous-{os.environ['GITHUB_RUN_ID']}.json"
        github.api(existing_asset["url"], {"name": previous_name}, "PATCH")
    try:
        final = response_object(
            github.api(staged["url"], {"name": SOURCE_ASSET}, "PATCH")
        )
        verify_asset(final, local_source)
    except Exception:
        if existing_asset:
            # A successful rename followed by failed verification must not block rollback.
            current_result = github.api(staged["url"], missing=True)
            current = (
                response_object(current_result) if current_result is not None else None
            )
            if current and current.get("name") == SOURCE_ASSET:
                github.api(staged["url"], method="DELETE")
            github.api(existing_asset["url"], {"name": SOURCE_ASSET}, "PATCH")
        raise
    if existing_asset:
        github.api(existing_asset["url"], method="DELETE")
    return final["browser_download_url"]


def publish(out: Path) -> None:
    validate_inputs()
    version, build = os.environ["RELEASE_VERSION"], os.environ["BUILD_NUMBER"]
    names = verify_archives(out, version, build)
    pubspec = os.environ["PUBSPEC_VERSION"]
    if pubspec != f"{version}+{build}":
        raise ValueError(
            "Manual release overrides are disabled; versions must match pubspec.yaml."
        )
    timestamp = datetime.datetime.now(datetime.UTC).isoformat()
    tag = f"frontend-v{version}+{build}"
    repo = os.environ["GITHUB_REPOSITORY"]
    from ios_source import create_source

    # Immutable release snapshot; subscriptions always use ios-source/apps.json.
    source_snapshot = create_source(
        out / names[1],
        f"https://github.com/{repo}/releases/download/{urllib.parse.quote(tag, safe='')}/{urllib.parse.quote(names[1], safe='')}",
        date=timestamp,
        icon_url=f"https://raw.githubusercontent.com/{repo}/main/frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png",
    )
    (out / SOURCE_ASSET).write_text(
        json.dumps(source_snapshot, indent=2) + "\n", encoding="utf-8"
    )
    toolchains = {
        platform: json.loads((out / f"{platform}-toolchain.json").read_text())
        for platform in ("android", "ios")
    }
    manifest = {
        "component": "frontend",
        "product_version": version,
        "build_number": build,
        "pubspec_version": pubspec,
        "source_sha": os.environ["SOURCE_SHA"],
        "workflow_sha": os.environ["WORKFLOW_SHA"],
        "workflow_run": os.environ["GITHUB_RUN_ID"],
        "built_at_utc": timestamp,
        "toolchains": toolchains,
        "backend_base_url": os.environ["BACKEND_BASE_URL"],
        "supported_api_major": 1,
        "contract_schema": "1",
        "report_version": "label-report-v1",
        "knowledge_version": "negotiated_at_runtime_and_retained_in_reports",
        "deployment": "not_deployed_by_this_workflow",
        "gates": {
            "flutter_analyze": "passed",
            "flutter_test": "passed",
            "android_build": "passed",
            "ios_device_build": "passed",
            "backend_contract_checks": "separate_backend_release_gate",
            "web_build": "not_in_this_workflow",
            "livecontainer_device_runtime": "unverified",
        },
        "android_signing": "demo_debug_key_not_production_identity",
        "ios_signing": "unsigned_requires_host_signing",
        "assets": [
            {"file": n, "bytes": (out / n).stat().st_size, "sha256": sha256(out / n)}
            for n in names
        ],
        "publication_requested": os.environ["PUBLISH_RELEASE"] == "true",
    }
    (out / "build-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    checksum_files = sorted(
        p.name for p in out.iterdir() if p.is_file() and p.name != "SHA256SUMS.txt"
    )
    (out / "SHA256SUMS.txt").write_text(
        "".join(f"{sha256(out / name)}  {name}\n" for name in checksum_files),
        encoding="utf-8",
    )
    github = GitHub()
    github.unused(tag)
    notes = (
        f"Frontend {version}+{build}, built from {os.environ['SOURCE_SHA']}.\n\n"
        "Android APK uses the registered stable demo key, not a production signing identity. "
        "The iPhoneOS IPA is unsigned and can be imported into LiveContainer for host signing, or signed separately. "
        "LiveContainer launch, camera, and account behavior require checks on your iPhone.\n\n"
        "Flutter analysis/tests and both native builds passed. Backend deployment and hosted API proof are separate. "
        "Build reports and hashes are retained in the workflow's frontend-release-evidence artifact.\n\n"
        f"Use the permanent [LiveContainer source](https://github.com/{repo}/releases/download/ios-source/apps.json) "
        "for automatic updates. The attached apps.json is a snapshot of this release; existing source subscriptions never change."
    )
    release = response_object(
        github.api(
            f"{github.root}/releases",
            {
                "tag_name": tag,
                "target_commitish": os.environ["SOURCE_SHA"],
                "name": f"Frontend v{version}+{build} — demo APK / unsigned iOS",
                "body": notes,
                "draft": True,
                "prerelease": True,
                "make_latest": "false",
            },
            "POST",
        )
    )
    expected = public_assets(out, names)
    for path in expected.values():
        github.upload(release, path)
    remote = response_object(github.api(f"{github.root}/releases/{release['id']}"))
    actual = {a["name"]: a for a in remote["assets"]}
    if set(actual) != set(expected):
        raise ValueError("Remote asset set differs; the release remains a draft.")
    for name, path in expected.items():
        verify_asset(actual[name], path)
    published = os.environ["PUBLISH_RELEASE"] == "true"
    source_url = None
    if published:
        github.api(remote["url"], {"draft": False, "make_latest": "false"}, "PATCH")
        remote = response_object(github.api(remote["url"]))
        if remote["draft"]:
            raise ValueError("GitHub did not publish the verified mobile release.")
        source_url = refresh_source(github, out / names[1], remote, timestamp)
    summary = Path(os.environ["GITHUB_STEP_SUMMARY"])
    with summary.open("a", encoding="utf-8") as stream:
        stream.write(
            f"{'Published' if published else 'Draft created'}: [{tag}]({remote['html_url']}).\n"
        )
        if source_url:
            stream.write(
                f"LiveContainer source: [{SOURCE_ASSET}]({source_url}). Unsigned IPA; device runtime remains unverified.\n"
            )
    print(f"{'Published' if published else 'Draft'} mobile release: {tag}")


def public_assets(out: Path, archives: list[str]) -> dict[str, Path]:
    """Publish only the two validated apps and the source snapshot."""
    return {name: out / name for name in [*archives, SOURCE_ASSET]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight", "publish"))
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    args = parser.parse_args()
    validate_inputs()
    if args.command == "preflight":
        GitHub().unused(
            f"frontend-v{os.environ['RELEASE_VERSION']}+{os.environ['BUILD_NUMBER']}"
        )
    else:
        publish(args.dist)


if __name__ == "__main__":
    main()
