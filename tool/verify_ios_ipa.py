"""Check release metadata and embedded framework deployment targets before upload."""

import argparse
from pathlib import Path, PurePosixPath
import plistlib
import subprocess
import tempfile
from zipfile import ZipFile


def version(value):
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * max(0, 3 - len(parts))


def binary_minimum_versions(binary):
    output = subprocess.check_output(
        ["xcrun", "vtool", "-show-build", str(binary)], text=True
    )
    command = None
    platform = None
    minimums = []
    for line in output.splitlines():
        fields = line.split()
        if len(fields) != 2:
            continue
        key, value = fields
        if key == "cmd":
            command, platform = value, None
        elif key == "platform":
            platform = value
        elif command == "LC_BUILD_VERSION" and key == "minos":
            if platform != "IOS":
                raise ValueError(f"Unexpected framework platform: {platform}")
            minimums.append(version(value))
        elif command == "LC_VERSION_MIN_IPHONEOS" and key == "version":
            minimums.append(version(value))
    if not minimums:
        raise ValueError("Framework binary has no iOS deployment target")
    return minimums


def verify(ipa_path, expected_version, expected_build, expected_bundle):
    with ZipFile(ipa_path) as ipa, tempfile.TemporaryDirectory() as directory:
        app_plists = [
            name
            for name in ipa.namelist()
            if len(PurePosixPath(name).parts) == 3
            and PurePosixPath(name).parts[0] == "Payload"
            and PurePosixPath(name).parts[1].endswith(".app")
            and PurePosixPath(name).name == "Info.plist"
        ]
        if len(app_plists) != 1:
            raise ValueError("IPA must contain exactly one main app Info.plist")
        info = plistlib.loads(ipa.read(app_plists[0]))
        for key, expected in {
            "CFBundleShortVersionString": expected_version,
            "CFBundleVersion": expected_build,
            "CFBundleIdentifier": expected_bundle,
        }.items():
            if info.get(key) != expected:
                raise ValueError(f"IPA {key} is missing or differs from build settings")

        app_path = PurePosixPath(app_plists[0]).parent
        frameworks = app_path / "Frameworks"
        count = 0
        for name in ipa.namelist():
            path = PurePosixPath(name)
            if path.name != "Info.plist" or not path.parent.name.endswith(".framework"):
                continue
            if not path.is_relative_to(frameworks):
                continue
            framework_info = plistlib.loads(ipa.read(name))
            declared = framework_info.get("MinimumOSVersion")
            if not declared:
                raise ValueError(f"{path.parent.name} has no MinimumOSVersion")
            executable = framework_info.get("CFBundleExecutable")
            if not executable or PurePosixPath(executable).name != executable:
                raise ValueError(f"{path.parent.name} has an invalid executable")
            binary = Path(directory) / "framework"
            binary.write_bytes(ipa.read(str(path.parent / executable)))
            if any(minimum > version(declared) for minimum in binary_minimum_versions(binary)):
                raise ValueError(
                    f"{path.parent.name}: binary requires a newer iOS version "
                    f"than MinimumOSVersion {declared}"
                )
            count += 1
        print(f"Verified IPA {expected_version} ({expected_build}) and {count} frameworks")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()
    try:
        verify(args.ipa, args.version, args.build_number, args.bundle_id)
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
