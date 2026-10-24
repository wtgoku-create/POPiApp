#!/usr/bin/env bash
set -euo pipefail
deployment_release=${1:?release identifier required}
[[ "$deployment_release" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]
release_directory="/opt/popi-harness/releases/$deployment_release"
test -f "$release_directory/.qualified"
if systemctl is-active --quiet popi-harness.service; then
  printf 'An existing POPi service is active; stage completed without restarting it.\n'
  exit 3
fi

# Secrets never enter either the source release or the public Web root.
if [[ -f /etc/popi-harness/model.json ]]; then
  install -d -m 0700 "/etc/popi-harness/backup-$deployment_release"
  cp -p /etc/popi-harness/model.json /etc/popi-harness/huimengi.json /etc/popi-harness/.credentials.yaml /etc/popi-harness/service.env "/etc/popi-harness/backup-$deployment_release/"
fi
tar --extract --gzip --file /opt/popi-harness/private-config.tar.gz --directory /etc/popi-harness --no-same-owner
chown popi-harness:popi-harness /etc/popi-harness/model.json /etc/popi-harness/huimengi.json /etc/popi-harness/.credentials.yaml /etc/popi-harness/service.env
chmod 0600 /etc/popi-harness/model.json /etc/popi-harness/huimengi.json /etc/popi-harness/.credentials.yaml /etc/popi-harness/service.env
rm /opt/popi-harness/private-config.tar.gz
ln -s "$release_directory" /opt/popi-harness/current.next
mv -Tf /opt/popi-harness/current.next /opt/popi-harness/current
install -m 0644 "$release_directory/deploy/harness/popi-harness.service" /etc/systemd/system/popi-harness.service
systemctl daemon-reload
systemctl enable --now popi-harness.service
printf 'Harness installed; check loopback health before publishing the site.\n'
