#!/usr/bin/env bash
set -euo pipefail
deployment_release=${1:?release identifier required}
[[ "$deployment_release" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]
release_directory="/opt/popi-harness/releases/$deployment_release"
test ! -e "$release_directory"
install -d -m 0755 "$release_directory"
tar --extract --gzip --file /opt/popi-harness/harness-release.tar.gz --directory "$release_directory" --no-same-owner

export PATH="/opt/popi-harness/node/bin:/usr/bin:/bin"
cd "$release_directory/services/agent/runtime"
npm ci --ignore-scripts --no-audit --no-fund --cache /opt/popi-harness/npm-cache > "$release_directory/npm-install.log" 2>&1
chmod -R u=rwX,go=rX "$release_directory"
node paths.mjs seal
node paths.mjs verify
cd "$release_directory"
node --test --test-concurrency=2 services/agent/local/*.test.mjs > "$release_directory/backend-tests.log" 2>&1
DSH_NODE_BIN=/opt/popi-harness/node/bin/node sh services/agent/m0/run-local-harness.sh > "$release_directory/sdk-m0.log" 2>&1
touch "$release_directory/.qualified"
bash "$release_directory/deploy/harness/activate-server.sh" "$deployment_release"
