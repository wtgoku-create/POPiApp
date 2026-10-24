"""Validate and sanitize inputs and outputs for the macOS notarization job."""

import argparse
import json
from pathlib import Path, PurePosixPath
import re
from urllib.parse import urlsplit


SUBMISSION_ID = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)
SAFE_DOWNLOAD_PATH = re.compile(
    r"^/downloads/POPi-macos-[A-Za-z0-9][A-Za-z0-9._-]*\.dmg$"
)
SAFE_SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
SAFE_STATUS = re.compile(r"^[A-Za-z][A-Za-z0-9 _-]{0,79}$")


def validate_input(url: str, checksum: str) -> None:
    parsed = urlsplit(url)
    filename = PurePosixPath(parsed.path).name
    if (
        parsed.scheme != "https"
        or parsed.netloc != "124.222.185.31"
        or parsed.query
        or parsed.fragment
        or not SAFE_DOWNLOAD_PATH.fullmatch(parsed.path)
        or ".." in filename
    ):
        raise ValueError("macOS notarization URL is outside the approved download path")
    if not SAFE_SHA256.fullmatch(checksum):
        raise ValueError("macOS notarization SHA-256 must contain 64 hex characters")


def _write_github_outputs(
    path: Path,
    submission_id: str | None,
    status: str,
    accepted: bool,
) -> None:
    needs_log = submission_id is not None and status.lower() != "accepted"
    with path.open("a", encoding="utf-8") as destination:
        destination.write(
            f"submission_id={submission_id or ''}\n"
            f"status={status}\n"
            f"accepted={'true' if accepted else 'false'}\n"
            f"needs_log={'true' if needs_log else 'false'}\n"
        )


def parse_result(
    source: Path,
    output: Path,
    github_output: Path,
    notary_exit_code: int,
) -> bool:
    submission_id = None
    status = "Error"
    valid_json = False
    try:
        raw = json.loads(source.read_text(encoding="utf-8"))
        if isinstance(raw, dict):
            candidate_id = raw.get("id")
            candidate_status = raw.get("status")
            if isinstance(candidate_id, str) and SUBMISSION_ID.fullmatch(candidate_id):
                submission_id = candidate_id
            if (
                isinstance(candidate_status, str)
                and SAFE_STATUS.fullmatch(candidate_status)
            ):
                status = candidate_status
            valid_json = True
    except (OSError, json.JSONDecodeError):
        pass

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            {"submissionId": submission_id, "status": status},
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    accepted = (
        valid_json
        and notary_exit_code == 0
        and submission_id is not None
        and status.lower() == "accepted"
    )
    _write_github_outputs(github_output, submission_id, status, accepted)
    return accepted


def _safe_text(value: object, limit: int = 2000) -> str | None:
    if not isinstance(value, str):
        return None
    text = "".join(
        character
        for character in value
        if character >= " " or character == "\t"
    )
    text = re.sub(r"https?://\S+", "[URL removed]", text)
    text = re.sub(r"/(?:Users|private|var|tmp)/\S+", "[path removed]", text)
    return text[:limit]


def sanitize_log(source: Path, output: Path) -> None:
    try:
        raw = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError("Apple notarization log could not be read") from error
    if not isinstance(raw, dict):
        raise ValueError("Apple notarization log must be an object")

    sanitized: dict[str, object] = {}
    for key in ("jobId", "status", "statusSummary", "statusCode", "archiveFilename", "sha256"):
        value = raw.get(key)
        if isinstance(value, (str, int)) and not isinstance(value, bool):
            sanitized[key] = _safe_text(value) if isinstance(value, str) else value

    issues = raw.get("issues")
    if isinstance(issues, list):
        sanitized_issues = []
        for issue in issues[:200]:
            if not isinstance(issue, dict):
                continue
            item = {}
            for key in ("severity", "code", "path", "message", "architecture"):
                value = issue.get(key)
                if isinstance(value, (str, int)) and not isinstance(value, bool):
                    item[key] = _safe_text(value) if isinstance(value, str) else value
            sanitized_issues.append(item)
        sanitized["issues"] = sanitized_issues

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(sanitized, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate-input")
    validate_parser.add_argument("--url", required=True)
    validate_parser.add_argument("--sha256", required=True)

    result_parser = subparsers.add_parser("result")
    result_parser.add_argument("--input", required=True, type=Path)
    result_parser.add_argument("--output", required=True, type=Path)
    result_parser.add_argument("--github-output", required=True, type=Path)
    result_parser.add_argument("--notary-exit-code", required=True, type=int)

    log_parser = subparsers.add_parser("sanitize-log")
    log_parser.add_argument("--input", required=True, type=Path)
    log_parser.add_argument("--output", required=True, type=Path)

    args = parser.parse_args()
    try:
        if args.command == "validate-input":
            validate_input(args.url, args.sha256)
        elif args.command == "result":
            accepted = parse_result(
                args.input,
                args.output,
                args.github_output,
                args.notary_exit_code,
            )
            if not accepted:
                raise SystemExit(1)
        else:
            sanitize_log(args.input, args.output)
    except ValueError as error:
        raise SystemExit(str(error)) from error
