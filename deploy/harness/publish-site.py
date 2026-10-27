"""Publish a qualified Web release, preserving the existing Caddy configuration."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

release = sys.argv[1]
if len(release) != 16 or not release[:8].isdigit() or release[8] != "T" or not release[9:15].isdigit() or release[-1] != "Z":
    raise ValueError("Invalid release identifier")
root = Path(f"/srv/popi-web/releases/{release}")
metadata = json.loads((root / "deployment.json").read_text())
assert metadata["release"] == release
assert metadata["javascriptSha256"] == hashlib.sha256((root / "main.dart.js").read_bytes()).hexdigest()
assert Path(f"/opt/popi-harness/releases/{release}/.qualified").is_file()
health = json.load(urllib.request.urlopen("http://127.0.0.1:3084/health", timeout=15))
assert health["configured"] is True

configuration = Path("/etc/caddy/Caddyfile")
original = configuration.read_bytes()
backup = configuration.with_name(f"Caddyfile.before-popi-{release}")
if backup.exists():
    raise RuntimeError("A deployment backup with this release already exists")
backup.write_bytes(original)
backup.chmod(0o600)
directive = "import /etc/caddy/popi-harness.caddy"
candidate = configuration.with_name("Caddyfile.popi-candidate")
text = original.decode()
if "default_sni" not in text:
    if text.lstrip().startswith("{"):
        raise RuntimeError("Merge the IP default_sni into the existing Caddy global block first")
    text = "{\n\tdefault_sni 124.222.185.31\n}\n\n" + text
candidate.write_text(text if directive in text else text.rstrip() + "\n\n" + directive + "\n")
candidate.chmod(configuration.stat().st_mode & 0o777)
subprocess.run(["caddy", "validate", "--config", str(candidate), "--adapter", "caddyfile"], check=True)

current = Path("/srv/popi-web/current")
previous = os.readlink(current) if current.is_symlink() else None
if current.exists() and not current.is_symlink():
    raise RuntimeError("The existing Web path is not a managed release symlink")
next_link = current.with_name("current.next")
next_link.symlink_to(root)
os.replace(next_link, current)
os.replace(candidate, configuration)
try:
    subprocess.run(["systemctl", "reload", "caddy"], check=True)
except Exception:
    configuration.write_bytes(original)
    if previous is None:
        current.unlink()
    else:
        next_link.symlink_to(previous)
        os.replace(next_link, current)
    subprocess.run(["systemctl", "reload", "caddy"], check=True)
    raise
print(json.dumps({"release": release, "published": True, "url": "https://124.222.185.31", "caddyBackup": str(backup)}))
