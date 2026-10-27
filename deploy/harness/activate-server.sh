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

# Store v2 is migrated atomically on first start but older releases cannot read
# it. Preserve the inactive pre-migration journal so a rollback can restore the
# old release and matching schema together. Owned bytes and job directories are
# content-addressed or ignored by old releases and remain in place.
if [[ -f /var/lib/popi-harness/store.json ]]; then
  state_backup="/var/lib/popi-harness/release-backups/$deployment_release"
  previous_release=""
  if [[ -L /opt/popi-harness/current ]]; then
    previous_release=$(readlink -f /opt/popi-harness/current)
    [[ "$previous_release" == /opt/popi-harness/releases/* ]]
    test -d "$previous_release"
  fi
  if [[ -e "$state_backup" ]]; then
    test -f "$state_backup/store.json"
    cmp --silent /var/lib/popi-harness/store.json "$state_backup/store.json"
    if [[ -n "$previous_release" ]]; then
      test -f "$state_backup/previous-release"
      test "$(cat "$state_backup/previous-release")" = "$previous_release"
    fi
  else
    install -d -m 0700 -o popi-harness -g popi-harness "$state_backup"
    cp -p /var/lib/popi-harness/store.json "$state_backup/store.json"
    if [[ -n "$previous_release" ]]; then
      printf '%s\n' "$previous_release" > "$state_backup/previous-release"
    fi
    chown popi-harness:popi-harness "$state_backup/store.json"
    chmod 0600 "$state_backup/store.json"
    if [[ -f "$state_backup/previous-release" ]]; then
      chown popi-harness:popi-harness "$state_backup/previous-release"
      chmod 0600 "$state_backup/previous-release"
    fi
  fi
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
install -m 0644 "$release_directory/deploy/harness/popi-document-converter.service" /etc/systemd/system/popi-document-converter.service
systemctl daemon-reload
systemctl enable popi-document-converter.service
systemctl restart popi-document-converter.service
for attempt in {1..20}; do
  [[ ! -S /run/popi-document-converter/convert.sock ]] || break
  sleep 0.25
done
test -S /run/popi-document-converter/convert.sock
systemctl enable --now popi-harness.service
printf 'Harness installed; check loopback health before publishing the site.\n'
