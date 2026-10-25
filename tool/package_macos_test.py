"""Sign an isolated remote-Harness Mac application and create its installer."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess


def run(*args: str) -> str:
    result = subprocess.run(args, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def package(args: argparse.Namespace) -> dict:
    source = args.source.resolve(strict=True)
    output = args.output.resolve()
    if source.suffix != ".app" or not source.is_dir():
        raise ValueError("Source must be a built .app directory")
    if re.fullmatch(r"[A-Z0-9]{10}", args.team) is None:
        raise ValueError("Invalid signing team identifier")
    if args.bundle_id != "com.popistudio.app.harness.remote":
        raise ValueError("Use the isolated remote-Harness bundle identifier")
    output.mkdir(parents=True, exist_ok=False)
    contents = output / "installer"
    contents.mkdir()
    app = contents / "POPi Test.app"
    run("ditto", str(source), str(app))
    info_path = app / "Contents/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info.update({
        "CFBundleIdentifier": args.bundle_id,
        "CFBundleDisplayName": "POPi 测试版",
        "CFBundleName": "POPi Test",
    })
    info_path.write_bytes(plistlib.dumps(info))

    # Developer ID apps without an embedded distribution provisioning profile
    # may claim App Sandbox entitlements, but not restricted keychain groups or
    # application/team identifiers. Code signing supplies the signing identity;
    # the app uses its private file-based macOS keychain instead of sharing one.
    entitlements = plistlib.loads(args.entitlements.read_bytes())
    entitlements.pop("com.apple.security.get-task-allow", None)
    for restricted in (
        "keychain-access-groups",
        "com.apple.application-identifier",
        "com.apple.developer.team-identifier",
    ):
        entitlements.pop(restricted, None)
    entitlements_path = output / "distribution.entitlements"
    entitlements_path.write_bytes(plistlib.dumps(entitlements))

    magic_values = {
        b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
        b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    }
    binaries = []
    for path in (app / "Contents/Frameworks").rglob("*"):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open("rb") as binary:
            if binary.read(4) in magic_values:
                binaries.append(path)
    sign_args = (
        "codesign", "--force", "--timestamp", "--options", "runtime",
        "--sign", args.identity,
    )
    for binary in sorted(binaries, key=lambda path: len(path.parts), reverse=True):
        run(*sign_args, str(binary))
    frameworks = (app / "Contents/Frameworks").rglob("*.framework")
    for framework in sorted(frameworks, key=lambda path: len(path.parts), reverse=True):
        if not framework.is_symlink():
            run(*sign_args, str(framework))
    run(*sign_args, "--entitlements", str(entitlements_path), str(app))
    run("codesign", "--verify", "--deep", "--strict", str(app))

    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = run("lipo", "-archs", str(executable)).split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise ValueError("Expected a universal Apple Silicon and Intel build")
    for binary in binaries:
        if set(run("lipo", "-archs", str(binary)).split()) != set(architectures):
            raise ValueError(f"Framework architectures differ: {binary.name}")

    (contents / "Applications").symlink_to("/Applications")
    version = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    dmg = output / f"POPi-macos-{version}-{build}-universal.dmg"
    run("hdiutil", "create", "-volname", "POPi Test", "-srcfolder", str(contents),
        "-format", "UDZO", str(dmg))
    run(*sign_args, str(dmg))
    run("codesign", "--verify", "--strict", str(dmg))
    metadata = {
        "platform": "macos", "version": version, "build": build,
        "bundleId": args.bundle_id, "teamId": args.team,
        "architectures": architectures, "minimumOS": info["LSMinimumSystemVersion"],
        "env": "harness_remote", "target": "lib/main_harness.dart",
        "signatureVerified": True, "notarized": False,
        "app": str(app), "dmg": str(dmg), "bytes": dmg.stat().st_size,
        "sha256": digest(dmg),
    }
    (output / "macos-harness.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--team", default="84GT698GKX")
    parser.add_argument("--bundle-id", default="com.popistudio.app.harness.remote")
    parser.add_argument("--entitlements", type=Path,
                        default=Path("macos/Runner/Release.entitlements"))
    print(json.dumps(package(parser.parse_args()), ensure_ascii=False))
