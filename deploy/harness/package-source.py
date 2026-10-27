"""Package the working-tree Harness source, including its runtime YAML overlays."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument("--harness-source", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--release", default=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
sources = []
vendor_directory = args.harness_source / "services/agent/local/style-film-vendor"
skills_directory = args.harness_source / "services/agent/local/skills"
for directory in ["services/agent/local", "services/agent/runtime", "services/agent/m0"]:
    for path in (args.harness_source / directory).rglob("*"):
        relative = path.relative_to(args.harness_source)
        if not path.is_file() or path.is_symlink():
            continue
        if any(part.startswith(".") or part in {"node_modules", "evidence"} for part in relative.parts):
            continue
        if path.name in {"model.json", "huimengi.json", "credentials.yaml"}:
            raise ValueError("Private configuration cannot enter a source release")
        vendor_asset = path.is_relative_to(vendor_directory) and (
            path.suffix.lower() in {".jpg", ".png", ".webp", ".otf", ".ttf", ".woff2", ".txt"}
            or path.name in {"LICENSE", "NOTICE"}
        )
        skill_asset = path.is_relative_to(skills_directory) and path.suffix.lower() in {
            ".md", ".txt", ".jpg", ".jpeg", ".png", ".webp", ".json", ".py", ".yml", ".yaml"
        }
        if vendor_asset or skill_asset or path.suffix in {".mjs", ".js", ".json", ".md", ".sh", ".py", ".yml", ".yaml"}:
            sources.append((path, str(relative)))
for name in ["services/agent/dev.mjs", "services/agent/runtime-lock.json"]:
    sources.append((args.harness_source / name, name))
for path in Path(__file__).parent.iterdir():
    if path.is_file() and not path.name.startswith("."):
        sources.append((path, "deploy/harness/" + path.name))
names = {name for _, name in sources}
if "services/agent/local/text-only.patch.yml" not in names:
    raise ValueError("Harness runtime overlay is missing")
for manifest_path in sorted(skills_directory.glob("*/manifest.json")):
    skill_root = manifest_path.parent
    if manifest_path.is_symlink() or skill_root.is_symlink():
        raise ValueError("Installed Skill manifest and root must not be symbolic links")
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("entry") != "SKILL.md" or not isinstance(manifest.get("files"), list):
        raise ValueError("Installed Skill manifest is invalid")
    expected_names = {"manifest.json"}
    for entry in manifest["files"]:
        name = entry.get("path", "")
        relative = Path(name)
        digest = entry.get("sha256", "")
        if (not name or relative.is_absolute() or ".." in relative.parts or "\\" in name
                or not re.fullmatch(r"[a-f0-9]{64}", digest) or name in expected_names):
            raise ValueError("Installed Skill manifest contains an invalid resource")
        expected_names.add(name)
        path = skill_root / relative
        if (not path.is_file() or path.is_symlink()
                or not path.resolve().is_relative_to(skill_root.resolve())
                or any(parent.is_symlink() for parent in path.parents if parent.is_relative_to(skill_root))):
            raise ValueError("Installed Skill resources must be regular files inside the bundle")
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest or len(data) != entry.get("bytes"):
            raise ValueError(f"Installed Skill resource failed integrity verification: {name}")
        if str(path.relative_to(args.harness_source)) not in names:
            raise ValueError(f"Installed Skill resource would be missing from release: {name}")
    actual_entries = list(skill_root.rglob("*"))
    if any(path.is_symlink() or not (path.is_file() or path.is_dir()) for path in actual_entries):
        raise ValueError("Installed Skill contains an unsafe filesystem entry")
    actual_names = {str(path.relative_to(skill_root)) for path in actual_entries if path.is_file()}
    if actual_names != expected_names or "SKILL.md" not in expected_names:
        raise ValueError("Installed Skill bundle contains missing or unlisted files")
if vendor_directory.exists():
    vendor_manifest = json.loads((vendor_directory / "manifest.json").read_text())
    for name, expected in vendor_manifest["files"].items():
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts or "\\" in name:
            raise ValueError("Film vendor manifest contains an invalid path")
        path = vendor_directory / relative
        if (
            not path.is_file()
            or path.is_symlink()
            or not path.resolve().is_relative_to(vendor_directory.resolve())
            or any(parent.is_symlink() for parent in path.parents if parent.is_relative_to(vendor_directory))
        ):
            raise ValueError("Film vendor resources must be regular files inside the vendor directory")
        digest = expected.get("sha256", "")
        if not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ValueError("Film vendor manifest contains an invalid digest")
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest or len(data) != expected.get("bytes"):
            raise ValueError(f"Film vendor resource failed integrity verification: {name}")
        if str(path.relative_to(args.harness_source)) not in names:
            raise ValueError(f"Film vendor resource would be missing from release: {name}")
with tarfile.open(args.output / "harness-release.tar.gz", "w:gz") as archive:
    for path, name in sorted(sources, key=lambda entry: entry[1]):
        archive.add(path, arcname=name, recursive=False)
manifest = {
    "release": args.release,
    "files": {name: hashlib.sha256(path.read_bytes()).hexdigest() for path, name in sources},
}
(args.output / "source-manifest.json").write_text(json.dumps(manifest, indent=2))
(args.output / "release-id").write_text(args.release)
print(json.dumps({"release": args.release, "sourceFiles": len(sources)}))
