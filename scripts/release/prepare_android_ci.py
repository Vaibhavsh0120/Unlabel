"""Prepare the pinned Flutter Android toolchain before Gradle starts in CI."""

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path


def android_versions(flutter_root: Path) -> tuple[str, str]:
    extension = (
        flutter_root
        / "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
    )
    text = extension.read_text(encoding="utf-8")
    sdk = re.search(r"val compileSdkVersion: Int = (\d+)", text)
    ndk = re.search(r'val ndkVersion: String = "([\d.]+)"', text)
    if not sdk or not ndk:
        raise ValueError("Cannot resolve Android SDK/NDK from the pinned Flutter SDK.")
    return sdk[1], ndk[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--versions-only", action="store_true")
    args = parser.parse_args()
    flutter_root = Path(os.environ["FLUTTER_ROOT"])
    sdk, ndk = android_versions(flutter_root)
    if args.versions_only:
        sdk_root = os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"]
        print(f"compile_sdk={sdk}\nndk_version={ndk}\nsdk_root={sdk_root}")
        return
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit(
            "This helper configures GitHub's disposable build environment only."
        )
    java_home = Path(os.environ["JAVA_HOME"])
    subprocess.run([str(java_home / "bin/java"), "-version"], check=True)
    sdk_root = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    manager = shutil.which("sdkmanager")
    if not manager:
        manager = str(sdk_root / "cmdline-tools/latest/bin/sdkmanager")
    subprocess.run(
        [
            manager,
            f"--sdk_root={sdk_root}",
            f"platforms;android-{sdk}",
            "build-tools;36.0.0",
            f"ndk;{ndk}",
        ],
        check=True,
        timeout=1200,
    )
    if not (sdk_root / f"ndk/{ndk}/source.properties").is_file():
        raise SystemExit("NDK preparation did not create a complete installation.")
    gradle_home = Path(os.environ["GRADLE_USER_HOME"])
    gradle_home.mkdir(parents=True, exist_ok=True)
    (gradle_home / "gradle.properties").write_text(
        "# Disposable CI overrides; leave the developer Gradle settings intact.\n"
        "org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -Dfile.encoding=UTF-8\n"
        "org.gradle.workers.max=2\n"
        "org.gradle.vfs.watch=false\n"
        "org.gradle.caching=true\n",
        encoding="utf-8",
    )
    print(
        f"Android SDK {sdk}, NDK {ndk}; Gradle uses 4 GB heap, two workers, no VFS watcher."
    )


if __name__ == "__main__":
    main()
