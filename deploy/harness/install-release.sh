#!/usr/bin/env bash
set -euo pipefail
deployment_release=${1:?release identifier required}
[[ "$deployment_release" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]
release_directory="/opt/popi-harness/releases/$deployment_release"
test ! -e "$release_directory"
install -d -m 0755 "$release_directory"
tar --extract --gzip --file /opt/popi-harness/harness-release.tar.gz --directory "$release_directory" --no-same-owner

export PATH="/opt/popi-harness/node/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$release_directory/services/agent/runtime"
npm ci --ignore-scripts --no-audit --no-fund --cache /opt/popi-harness/npm-cache > "$release_directory/npm-install.log" 2>&1
chmod -R u=rwX,go=rX "$release_directory"
node paths.mjs seal
node paths.mjs verify
bash "$release_directory/deploy/harness/prepare-document-runtime.sh"

# The byte-only converter has no access to Harness credentials. Bootstrap it
# from the staged immutable source on the first document-capable deployment.
if ! systemctl is-active --quiet popi-document-converter.service; then
  sed "s@/opt/popi-harness/current/services/agent/local/document-converter-daemon.py@$release_directory/services/agent/local/document-converter-daemon.py@" \
    "$release_directory/deploy/harness/popi-document-converter.service" \
    > /etc/systemd/system/popi-document-converter.service
  chmod 0644 /etc/systemd/system/popi-document-converter.service
  systemctl daemon-reload
  systemctl enable --now popi-document-converter.service
fi
for attempt in {1..20}; do
  [[ ! -S /run/popi-document-converter/convert.sock ]] || break
  sleep 0.25
done
test -S /run/popi-document-converter/convert.sock
test "$(stat -c '%U:%G:%a' /run/popi-document-converter/convert.sock)" = 'popi-document-converter:popi-harness:660'

film_chrome=""
for candidate in /usr/bin/google-chrome-stable /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
  if [[ -x "$candidate" ]]; then
    film_chrome="$candidate"
    break
  fi
done
test -n "$film_chrome"
command -v runuser >/dev/null

# Browser sandbox behavior and private writable paths must match the final
# service account. Restore immutable release ownership on every exit path so a
# failed qualification cannot leave a user-owned executable tree behind.
test_directory=$(mktemp -d /tmp/popi-qualify.XXXXXX)
chmod 0700 "$test_directory"
chown popi-harness:popi-harness "$test_directory"
restore_release_owner() {
  chown -R root:root "$release_directory"
  chmod -R u=rwX,go=rX "$release_directory"
}
cleanup_qualification() {
  local cleanup_status=0
  if [[ -d "$test_directory" ]]; then
    [[ "$test_directory" =~ ^/tmp/popi-qualify\.[a-zA-Z0-9]+$ ]] || cleanup_status=$?
    test ! -L "$test_directory" || cleanup_status=$?
    test "$(realpath -- "$test_directory")" = "$test_directory" || cleanup_status=$?
    test "$(stat -c '%U:%G' -- "$test_directory")" = "popi-harness:popi-harness" || cleanup_status=$?
    if [[ "$cleanup_status" -eq 0 ]]; then
      rm -rf --one-file-system -- "$test_directory" || cleanup_status=$?
    fi
  fi
  restore_release_owner || cleanup_status=$?
  return "$cleanup_status"
}
trap cleanup_qualification EXIT
chown -R popi-harness:popi-harness "$release_directory"

run_as_harness() {
  runuser --user popi-harness -- env \
    HOME=/var/lib/popi-harness \
    TMPDIR="$test_directory" \
    LOCAL_AGENT_FILM_CHROME_PATH="$film_chrome" \
    PATH="$PATH" \
    "$@"
}

test "$(run_as_harness id -u)" != "0"
run_as_harness "$film_chrome" --version > "$release_directory/chrome-version.log" 2>&1
cd "$release_directory"
run_as_harness /opt/popi-harness/node/bin/node --test --test-concurrency=2 services/agent/local/*.test.mjs > "$release_directory/backend-tests.log" 2>&1
run_as_harness env DSH_NODE_BIN=/opt/popi-harness/node/bin/node sh services/agent/m0/run-local-harness.sh > "$release_directory/sdk-m0.log" 2>&1
cleanup_qualification
trap - EXIT
touch "$release_directory/.qualified"
bash "$release_directory/deploy/harness/activate-server.sh" "$deployment_release"
