"""Verify a CI-built Android APK with Android SDK tools."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def _build_tools_directory() -> Path:
    sdk_root = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not sdk_root:
        raise ValueError("Android SDK root is not configured")
    root = Path(sdk_root) / "build-tools"
    directories = [path for path in root.iterdir() if path.is_dir()]
    if not directories:
        raise ValueError("Android SDK build tools are not installed")

    def version_key(path: Path) -> tuple[int, ...]:
        parts = re.findall(r"\d+", path.name)
        return tuple(int(part) for part in parts)

    return max(directories, key=version_key)


def _run(tool: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            [str(tool), *args],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError(f"{tool.name} verification failed") from error
    return result.stdout


def verify(
    apk: Path,
    expected_package: str,
    expected_version: str,
    expected_build: str,
    minimum_sdk: int,
    maximum_sdk: int,
) -> dict[str, object]:
    if not apk.is_file():
        raise ValueError("APK file does not exist")
    tools = _build_tools_directory()
    apksigner = tools / "apksigner"
    aapt = tools / "aapt"
    if not apksigner.is_file() or not aapt.is_file():
        raise ValueError("Required Android SDK verification tools are missing")

    _run(apksigner, "verify", "--verbose", str(apk))
    badging = _run(aapt, "dump", "badging", str(apk))
    package = re.search(
        r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",
        badging,
        re.MULTILINE,
    )
    sdk = re.search(r"^sdkVersion:'(\d+)'", badging, re.MULTILINE)
    if package is None or sdk is None:
        raise ValueError("APK manifest metadata could not be read")

    package_name, build, version = package.groups()
    min_sdk = int(sdk.group(1))
    if package_name != expected_package:
        raise ValueError("APK package name differs from the expected application ID")
    if version != expected_version or build != expected_build:
        raise ValueError("APK version metadata differs from the CI build settings")
    if not minimum_sdk <= min_sdk <= maximum_sdk:
        raise ValueError(
            f"APK minSdk {min_sdk} is outside the supported range "
            f"{minimum_sdk}..{maximum_sdk}"
        )
    print(
        f"Verified signed APK {expected_package} {expected_version} "
        f"({expected_build}), minSdk {min_sdk}"
    )
    return {
        "applicationId": package_name,
        "version": version,
        "build": build,
        "minSdk": min_sdk,
        "signatureVerified": True,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--minimum-sdk", type=int, default=21)
    parser.add_argument("--maximum-sdk", type=int, default=30)
    parser.add_argument("--metadata-output", type=Path)
    args = parser.parse_args()
    try:
        metadata = verify(
            args.apk,
            args.package,
            args.version,
            args.build_number,
            args.minimum_sdk,
            args.maximum_sdk,
        )
        if args.metadata_output is not None:
            args.metadata_output.parent.mkdir(parents=True, exist_ok=True)
            args.metadata_output.write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    except ValueError as error:
        raise SystemExit(str(error)) from error
