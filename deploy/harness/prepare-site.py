"""Stage the authenticated HTTPS site without reloading existing Caddy services."""

import grp
import os
from pathlib import Path
import subprocess
import sys

release = sys.argv[1]
if len(release) != 16 or not release[:8].isdigit() or release[8] != "T" or not release[9:15].isdigit() or release[-1] != "Z":
    raise ValueError("Invalid release identifier")
template = Path(f"/opt/popi-harness/releases/{release}/deploy/harness/site.caddy.template")
access_path = Path("/root/.popi-harness-web-access.json")
if not access_path.is_file():
    raise RuntimeError("Prepare the private access gateway credentials first")
assert Path("/etc/popi-access/access.json").is_file()
subprocess.run(["systemctl", "is-active", "--quiet", "popi-access.service"], check=True)
site = Path("/etc/caddy/popi-harness.caddy")
previous_site = site.read_bytes() if site.exists() else None
site.write_text(template.read_text())
site.chmod(0o640)
os.chown(site, 0, grp.getgrnam("caddy").gr_gid)
original = Path("/etc/caddy/Caddyfile").read_text()
if "default_sni" not in original:
    if original.lstrip().startswith("{"):
        raise RuntimeError("Merge the IP default_sni into the existing Caddy global block first")
    original = "{\n\tdefault_sni 124.222.185.31\n}\n\n" + original
directive = "import /etc/caddy/popi-harness.caddy"
candidate = Path("/etc/caddy/Caddyfile.popi-candidate")
candidate.write_text(original if directive in original else original.rstrip() + "\n\n" + directive + "\n")
candidate.chmod(0o600)
try:
    subprocess.run(["caddy", "validate", "--config", str(candidate), "--adapter", "caddyfile"], check=True)
except Exception:
    if previous_site is None:
        site.unlink()
    else:
        site.write_bytes(previous_site)
    raise
print("Authenticated HTTPS site staged and validated; existing Caddy config is still active.")
