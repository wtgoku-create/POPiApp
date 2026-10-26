"""Write public, reproducible metadata for a CI-built application artifact."""

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--platform", required=True, choices=("android", "ios"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--android-verification", type=Path)
    args = parser.parse_args()

    if not args.artifact.is_file():
        raise SystemExit("Build artifact does not exist")
    metadata = {
        "platform": args.platform,
        "version": args.version,
        "build": args.build_number,
        "env": args.environment,
        "target": args.target,
        "commit": args.commit,
        "sha256": sha256(args.artifact),
    }
    if args.platform == "android":
        if args.android_verification is None:
            raise SystemExit("Android verification metadata is required")
        try:
            verification = json.loads(
                args.android_verification.read_text(encoding="utf-8")
            )
        except (OSError, json.JSONDecodeError) as error:
            raise SystemExit("Android verification metadata could not be read") from error
        if not isinstance(verification, dict):
            raise SystemExit("Android verification metadata must be an object")
        if (
            verification.get("version") != args.version
            or verification.get("build") != args.build_number
        ):
            raise SystemExit(
                "Android verification metadata differs from the CI build settings"
            )
        application_id = verification.get("applicationId")
        min_sdk = verification.get("minSdk")
        if not isinstance(application_id, str) or not application_id:
            raise SystemExit("Android verification applicationId is invalid")
        if not isinstance(min_sdk, int) or isinstance(min_sdk, bool) or min_sdk < 1:
            raise SystemExit("Android verification minSdk is invalid")
        if verification.get("signatureVerified") is not True:
            raise SystemExit("Android signature has not been verified")
        metadata.update(
            {
                "applicationId": application_id,
                "minSdk": min_sdk,
                "signatureVerified": True,
            }
        )
    elif args.android_verification is not None:
        raise SystemExit("Android verification metadata is only valid for Android")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
