"""Atomically publish one CI-verified Android Harness build.

The CI metadata is deliberately strict: it is both the public download
metadata and the attestation that Android SDK tooling verified the package,
version, minimum SDK, and signature before this script receives the APK.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


DOWNLOADS_BEGIN = "\t\t# BEGIN POPI MOBILE DOWNLOADS"
DOWNLOADS_END = "\t\t# END POPI MOBILE DOWNLOADS"
EXPECTED_APPLICATION_ID = "com.popistudio.app"
EXPECTED_ENVIRONMENT = "harness_remote"
EXPECTED_TARGET = "lib/main_harness.dart"
MAX_APK_BYTES = 512 * 1024 * 1024
MAX_METADATA_BYTES = 64 * 1024
PUBLIC_METADATA_FIELDS = {
    "applicationId",
    "build",
    "commit",
    "env",
    "minSdk",
    "platform",
    "sha256",
    "signatureVerified",
    "target",
    "version",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _require_text(metadata: dict[str, object], field: str, pattern: str) -> str:
    value = metadata.get(field)
    if not isinstance(value, str) or re.fullmatch(pattern, value) is None:
        raise ValueError(f"Invalid public metadata field: {field}")
    return value


def _load_metadata(path: Path) -> dict[str, object]:
    if not path.is_file() or path.is_symlink():
        raise ValueError("Metadata must be a regular file")
    if path.stat().st_size > MAX_METADATA_BYTES:
        raise ValueError("Metadata is unexpectedly large")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Metadata is not valid UTF-8 JSON") from error
    if not isinstance(value, dict):
        raise ValueError("Metadata must be a JSON object")
    unknown = set(value) - PUBLIC_METADATA_FIELDS
    missing = PUBLIC_METADATA_FIELDS - set(value)
    if unknown or missing:
        raise ValueError(
            "Metadata fields differ from the public allowlist "
            f"(missing={sorted(missing)}, unknown={sorted(unknown)})"
        )
    return value


def _validate(apk: Path, metadata_path: Path) -> tuple[dict[str, object], str]:
    if not apk.is_file() or apk.is_symlink() or apk.suffix.lower() != ".apk":
        raise ValueError("APK must be a regular .apk file")
    size = apk.stat().st_size
    if size < 4 or size > MAX_APK_BYTES:
        raise ValueError("APK size is outside the accepted range")
    with apk.open("rb") as source:
        if source.read(4) not in (b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08"):
            raise ValueError("APK does not have a ZIP container header")

    metadata = _load_metadata(metadata_path)
    if metadata["platform"] != "android":
        raise ValueError("Only Android metadata can be published here")
    if metadata["env"] != EXPECTED_ENVIRONMENT:
        raise ValueError("APK was not built for the remote Harness environment")
    if metadata["target"] != EXPECTED_TARGET:
        raise ValueError("APK was not built from the Harness entry point")
    if metadata["applicationId"] != EXPECTED_APPLICATION_ID:
        raise ValueError("APK application ID attestation is incorrect")
    if metadata["signatureVerified"] is not True:
        raise ValueError("CI signature verification attestation is missing")
    if type(metadata["minSdk"]) is not int or metadata["minSdk"] != 24:
        raise ValueError("APK minimum SDK attestation is incorrect")

    _require_text(metadata, "version", r"[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?")
    _require_text(metadata, "build", r"[1-9][0-9]{0,11}")
    _require_text(metadata, "commit", r"[0-9a-f]{40}")
    expected_digest = _require_text(metadata, "sha256", r"[0-9a-f]{64}")
    actual_digest = _sha256(apk)
    if actual_digest != expected_digest:
        raise ValueError("APK SHA-256 differs from CI metadata")
    return metadata, actual_digest


def _download_block(apk_name: str, metadata_name: str, root: Path) -> str:
    # Names are constructed only from validated metadata and a SHA-256 prefix.
    root_text = str(root)
    return "\n".join(
        (
            DOWNLOADS_BEGIN,
            f"\t\t@popi_android_apk path /downloads/{apk_name}",
            "\t\thandle @popi_android_apk {",
            f"\t\t\troot * {root_text}",
            "\t\t\trewrite * /" + apk_name,
            "\t\t\theader Content-Type application/vnd.android.package-archive",
            f'\t\t\theader Content-Disposition "attachment; filename={apk_name}"',
            '\t\t\theader Cache-Control "no-store"',
            "\t\t\tfile_server",
            "\t\t}",
            f"\t\t@popi_android_metadata path /downloads/{metadata_name}",
            "\t\thandle @popi_android_metadata {",
            f"\t\t\troot * {root_text}",
            "\t\t\trewrite * /" + metadata_name,
            "\t\t\theader Content-Type application/json",
            '\t\t\theader Cache-Control "no-store"',
            "\t\t\tfile_server",
            "\t\t}",
            "\t\thandle /downloads/* {",
            "\t\t\trespond 404",
            "\t\t}",
            DOWNLOADS_END,
        )
    )


def _replace_download_block(site_text: str, replacement: str) -> str:
    begin_count = site_text.count(DOWNLOADS_BEGIN)
    end_count = site_text.count(DOWNLOADS_END)
    if begin_count == 0 and end_count == 0:
        # Support the already-deployed pre-download template. The anchor is
        # intentionally the exact authenticated catch-all route, and must be
        # unique; an unfamiliar site shape is rejected instead of guessed.
        anchor = "\t\thandle {\n\t\t\troute {\n\t\t\t\tforward_auth 127.0.0.1:3085"
        if site_text.count(anchor) != 1:
            raise ValueError("Caddy site has no managed block or unique insertion anchor")
        default_block = "\n".join(
            (
                DOWNLOADS_BEGIN,
                "\t\thandle /downloads/* {",
                "\t\t\trespond 404",
                "\t\t}",
                DOWNLOADS_END,
                "",
            )
        )
        site_text = site_text.replace(anchor, default_block + anchor, 1)
        begin_count = 1
        end_count = 1
    if begin_count != 1 or end_count != 1:
        raise ValueError("Caddy site does not contain one managed download block")
    start = site_text.index(DOWNLOADS_BEGIN)
    end = site_text.index(DOWNLOADS_END, start) + len(DOWNLOADS_END)
    if end <= start:
        raise ValueError("Managed Caddy download block is malformed")
    return site_text[:start] + replacement + site_text[end:]


def _run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def _atomic_copy(source: Path, destination: Path) -> bool:
    """Copy to destination once; return whether a new file was installed."""
    if destination.exists():
        if not destination.is_file() or destination.is_symlink():
            raise ValueError(f"Managed destination is not a regular file: {destination}")
        if _sha256(source) != _sha256(destination):
            raise ValueError(f"Managed destination already has different content: {destination}")
        return False
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", dir=destination.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as target, source.open("rb") as origin:
            shutil.copyfileobj(origin, target, length=1024 * 1024)
            target.flush()
            os.fsync(target.fileno())
        temporary.chmod(0o644)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return True


def _atomic_write(data: bytes, destination: Path, mode: int, uid: int, gid: int) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", dir=destination.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as target:
            target.write(data)
            target.flush()
            os.fsync(target.fileno())
        temporary.chmod(mode)
        os.chown(temporary, uid, gid)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def publish(args: argparse.Namespace) -> dict[str, object]:
    if args.apk.is_symlink() or args.metadata.is_symlink():
        raise ValueError("APK and metadata inputs must not be symbolic links")
    apk = args.apk.resolve(strict=True)
    metadata_path = args.metadata.resolve(strict=True)
    metadata, digest = _validate(apk, metadata_path)
    version = str(metadata["version"])
    build = str(metadata["build"])
    apk_name = f"POPi-android-{version}-{build}-{digest[:12]}.apk"
    metadata_name = f"POPi-android-{version}-{build}-{digest[:12]}.json"

    download_root = args.download_root
    if not download_root.is_absolute():
        raise ValueError("Download root must be absolute")
    if re.fullmatch(r"/[A-Za-z0-9._/-]+", str(download_root)) is None:
        raise ValueError("Download root contains unsupported Caddy path characters")
    download_root.mkdir(mode=0o755, parents=True, exist_ok=True)
    if download_root.is_symlink() or not download_root.is_dir():
        raise ValueError("Download root must be a real directory")
    download_root.chmod(0o755)

    public_metadata = dict(metadata)
    public_metadata["filename"] = apk_name
    public_metadata["bytes"] = apk.stat().st_size
    metadata_bytes = (
        json.dumps(public_metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")
    with tempfile.NamedTemporaryFile(dir=download_root, delete=False) as temporary_metadata:
        temporary_metadata.write(metadata_bytes)
        temporary_metadata.flush()
        os.fsync(temporary_metadata.fileno())
        public_metadata_path = Path(temporary_metadata.name)

    installed: list[Path] = []
    site = args.site
    if not site.is_file() or site.is_symlink():
        public_metadata_path.unlink(missing_ok=True)
        raise ValueError("Active POPi Caddy site must be a regular file")
    site_stat = site.stat()
    original_site = site.read_bytes()
    replacement = _download_block(apk_name, metadata_name, download_root)
    candidate_site = _replace_download_block(original_site.decode("utf-8"), replacement).encode(
        "utf-8"
    )
    original_site_digest = hashlib.sha256(original_site).hexdigest()
    backup = site.with_name(
        f"{site.name}.before-mobile-{digest[:12]}-{original_site_digest[:12]}"
    )

    try:
        if _atomic_copy(apk, download_root / apk_name):
            installed.append(download_root / apk_name)
        if _atomic_copy(public_metadata_path, download_root / metadata_name):
            installed.append(download_root / metadata_name)

        with tempfile.NamedTemporaryFile(
            prefix="popi-mobile-caddy-", suffix=".caddy", delete=False
        ) as candidate_file:
            candidate_file.write(candidate_site)
            candidate_file.flush()
            candidate_path = Path(candidate_file.name)
        try:
            _run(
                [
                    args.caddy,
                    "validate",
                    "--config",
                    str(candidate_path),
                    "--adapter",
                    "caddyfile",
                ]
            )
        finally:
            candidate_path.unlink(missing_ok=True)

        if candidate_site == original_site:
            _run(
                [
                    args.caddy,
                    "validate",
                    "--config",
                    str(args.caddyfile),
                    "--adapter",
                    "caddyfile",
                ]
            )
        else:
            if backup.exists():
                if backup.read_bytes() != original_site:
                    raise ValueError("Caddy backup for this artifact has different content")
            else:
                backup.write_bytes(original_site)
                backup.chmod(0o600)
            _atomic_write(
                candidate_site,
                site,
                site_stat.st_mode & 0o777,
                site_stat.st_uid,
                site_stat.st_gid,
            )
            try:
                _run(
                    [
                        args.caddy,
                        "validate",
                        "--config",
                        str(args.caddyfile),
                        "--adapter",
                        "caddyfile",
                    ]
                )
                _run([args.systemctl, "reload", "caddy"])
            except Exception:
                _atomic_write(
                    original_site,
                    site,
                    site_stat.st_mode & 0o777,
                    site_stat.st_uid,
                    site_stat.st_gid,
                )
                _run(
                    [
                        args.caddy,
                        "validate",
                        "--config",
                        str(args.caddyfile),
                        "--adapter",
                        "caddyfile",
                    ]
                )
                _run([args.systemctl, "reload", "caddy"])
                raise
    except Exception:
        for path in installed:
            path.unlink(missing_ok=True)
        raise
    finally:
        public_metadata_path.unlink(missing_ok=True)

    return {
        "applicationId": EXPECTED_APPLICATION_ID,
        "build": build,
        "metadataUrl": f"https://124.222.185.31/downloads/{metadata_name}",
        "published": True,
        "sha256": digest,
        "url": f"https://124.222.185.31/downloads/{apk_name}",
        "version": version,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path, help="CI-verified signed APK")
    parser.add_argument("metadata", type=Path, help="CI Android Harness metadata")
    parser.add_argument(
        "--download-root", type=Path, default=Path("/srv/popi-downloads")
    )
    parser.add_argument(
        "--site", type=Path, default=Path("/etc/caddy/popi-harness.caddy")
    )
    parser.add_argument("--caddyfile", type=Path, default=Path("/etc/caddy/Caddyfile"))
    parser.add_argument("--caddy", default="caddy")
    parser.add_argument("--systemctl", default="systemctl")
    return parser


if __name__ == "__main__":
    try:
        result = publish(_parser().parse_args())
    except (OSError, ValueError, UnicodeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
