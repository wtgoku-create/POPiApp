"""Prepare a private, independently sandboxed test-login service."""

import json
import os
from pathlib import Path
import pwd
import secrets
import subprocess

try:
    account = pwd.getpwnam("popi-access")
except KeyError:
    subprocess.run(["useradd", "--system", "--home-dir", "/nonexistent", "--shell", "/usr/sbin/nologin", "popi-access"], check=True)
    account = pwd.getpwnam("popi-access")
directory = Path("/etc/popi-access")
directory.mkdir(mode=0o700, exist_ok=True)
directory.chmod(0o700)
os.chown(directory, account.pw_uid, account.pw_gid)
owner_access = Path("/root/.popi-harness-web-access.json")
if owner_access.exists():
    access = json.loads(owner_access.read_text())
else:
    access = {"username": "popi", "password": secrets.token_urlsafe(15)}
    owner_access.write_text(json.dumps(access))
    owner_access.chmod(0o600)
configuration = directory / "access.json"
previous = json.loads(configuration.read_text()) if configuration.exists() else {}
configuration.write_text(json.dumps({**access, "sessionSecret": previous.get("sessionSecret") or secrets.token_hex(32)}))
configuration.chmod(0o600)
os.chown(configuration, account.pw_uid, account.pw_gid)
service = Path("/opt/popi-harness/current/deploy/harness/popi-access.service")
target = Path("/etc/systemd/system/popi-access.service")
target.write_bytes(service.read_bytes())
target.chmod(0o644)
subprocess.run(["systemd-analyze", "verify", str(target)], check=True)
subprocess.run(["systemctl", "daemon-reload"], check=True)
subprocess.run(["systemctl", "enable", "--now", "popi-access.service"], check=True)
print("Dedicated test access gateway configured; credentials remain private.")
