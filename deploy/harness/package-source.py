"""Package the working-tree Harness source, including its runtime YAML overlays."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument("--harness-source", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--release", default=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
sources = []
for directory in ["services/agent/local", "services/agent/runtime", "services/agent/m0"]:
    for path in (args.harness_source / directory).rglob("*"):
        relative = path.relative_to(args.harness_source)
        if not path.is_file() or path.is_symlink():
            continue
        if any(part.startswith(".") or part in {"node_modules", "evidence"} for part in relative.parts):
            continue
        if path.name in {"model.json", "huimengi.json", "credentials.yaml"}:
            raise ValueError("Private configuration cannot enter a source release")
        if path.suffix in {".mjs", ".js", ".json", ".md", ".sh", ".yml", ".yaml"}:
            sources.append((path, str(relative)))
for name in ["services/agent/dev.mjs", "services/agent/runtime-lock.json"]:
    sources.append((args.harness_source / name, name))
for path in Path(__file__).parent.iterdir():
    if path.is_file() and not path.name.startswith("."):
        sources.append((path, "deploy/harness/" + path.name))
names = {name for _, name in sources}
if "services/agent/local/text-only.patch.yml" not in names:
    raise ValueError("Harness runtime overlay is missing")
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
