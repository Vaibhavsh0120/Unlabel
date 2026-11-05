"""Classify release titles and select only a successful Actions-built app as Latest."""

import base64
import json
import os
import re
import urllib.request

from mobile_release import (
    GitHub,
    promote_frontend_release,
    response_list,
    response_object,
)
from version_metadata import parse_frontend_version


def validate_run(run: dict, repository: str) -> str:
    if (
        run.get("status") != "completed"
        or run.get("conclusion") != "success"
        or run.get("head_branch") != "main"
        or run.get("event") not in {"push", "workflow_dispatch"}
        or run.get("path") != ".github/workflows/frontend-release.yml"
        or run.get("head_repository", {}).get("full_name") != repository
        or not re.fullmatch(r"[0-9a-f]{40}", str(run.get("head_sha", "")))
    ):
        raise ValueError(
            "Latest requires a successful main-branch frontend release workflow."
        )
    return run["head_sha"]


def classified_title(release: dict) -> str:
    tag = release["tag_name"]
    if tag == "ios-source":
        return "Frontend - LiveContainer source (automatic updates)"
    names = [str(a.get("name", "")) for a in release.get("assets", [])]
    if any(n.endswith((".apk", ".ipa")) for n in names):
        version = tag.removeprefix("frontend-v").removeprefix("mobile-v")
        if tag == "v0.0.0":
            version = "0.0.0+1"
        return f"Frontend v{version} - Apps (demo APK / unsigned IPA)"
    title = release.get("name") or tag
    detail = re.sub(r"^(?:Frontend|Backend)\s+v?\S+\s*[-—–]?\s*", "", title)
    detail = re.sub(r"^(?:Web/source|API)\s*-\s*", "", detail)
    if tag.startswith("frontend-v"):
        return f"Frontend v{tag.removeprefix('frontend-v')} - Web/source - {detail}"
    if tag.startswith(("backend-v", "v")):
        version = tag.removeprefix("backend-v").removeprefix("v")
        return f"Backend v{version} - API - {detail}"
    return title


def matching_run(runs: list[dict], repository: str, sha: str) -> str:
    for run in runs:
        try:
            if validate_run(run, repository) == sha:
                return str(run["id"])
        except ValueError:
            continue
    raise ValueError(
        "The current feed has no matching successful frontend Actions run."
    )


def main() -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Latest selection runs only inside GitHub Actions.")
    github = GitHub()
    repository = os.environ["GITHUB_REPOSITORY"]
    run_id = os.environ.get("RELEASE_RUN_ID", "")
    with urllib.request.urlopen(
        f"https://github.com/{repository}/releases/download/ios-source/apps.json?verification_run={os.environ['GITHUB_RUN_ID']}",
        timeout=30,
    ) as response:
        raw = response.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        raise ValueError("Subscription feed exceeds its bounded read budget.")
    latest = json.loads(raw)["apps"][0]["versions"][0]
    if not run_id:
        # A later backend/manual publication must not displace the verified app.
        version, build = parse_frontend_version(
            f"version: {latest['version']}+{latest['buildVersion']}"
        )
        ref = response_object(
            github.api(f"{github.root}/git/ref/tags/frontend-v{version}%2B{build}")
        )
        runs = response_object(
            github.api(
                f"{github.root}/actions/workflows/frontend-release.yml/runs?branch=main&status=success&per_page=100"
            )
        )
        run_id = matching_run(
            response_list(runs["workflow_runs"]), repository, ref["object"]["sha"]
        )
    if not re.fullmatch(r"[1-9][0-9]*", run_id):
        raise ValueError("A numeric frontend release workflow run ID is required.")
    run = response_object(github.api(f"{github.root}/actions/runs/{run_id}"))
    sha = validate_run(run, os.environ["GITHUB_REPOSITORY"])
    content = response_object(
        github.api(f"{github.root}/contents/frontend/pubspec.yaml?ref={sha}")
    )
    version, build = parse_frontend_version(
        base64.b64decode(content["content"]).decode()
    )
    tag = f"frontend-v{version}+{build}"
    release = github.release(tag)
    if (
        not release
        or release.get("draft")
        or release.get("author", {}).get("login") != "github-actions[bot]"
    ):
        raise ValueError(
            "Only a published GitHub Actions-created frontend app can become Latest."
        )
    ref = response_object(
        github.api(f"{github.root}/git/ref/tags/{tag.replace('+', '%2B')}")
    )
    if ref.get("object", {}).get("sha") != sha:
        raise ValueError(
            "The app release tag does not match the successful workflow source."
        )
    ipa = next(
        a
        for a in release["assets"]
        if a["name"] == f"unlabel-{version}+{build}-ios-unsigned.ipa"
    )
    if (
        latest["version"] != version
        or latest["buildVersion"] != build
        or latest["downloadURL"] != ipa["browser_download_url"]
        or latest["size"] != ipa["size"]
        or ipa.get("digest") != f"sha256:{latest['sha256']}"
    ):
        raise ValueError(
            "The verified LiveContainer feed must match this exact app release."
        )
    changed = 0
    for page in range(1, 11):
        releases = response_list(
            github.api(f"{github.root}/releases?per_page=100&page={page}")
        )
        for item in releases:
            title = classified_title(item)
            if title != item.get("name"):
                github.api(
                    item["url"], {"name": title, "make_latest": "false"}, "PATCH"
                )
                changed += 1
        if len(releases) < 100:
            break
    promote_frontend_release(github, release)
    print(
        f"Latest: {tag}; successful Actions run {run_id}; classified {changed} release titles."
    )


if __name__ == "__main__":
    main()
