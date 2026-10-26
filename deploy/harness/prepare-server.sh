#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# This only prepares POPi-owned paths. Existing web/database services stay intact.
if ! id popi-harness >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/popi-harness --shell /usr/sbin/nologin popi-harness
fi
install -d -m 0755 /opt/popi-harness/releases /srv/popi-web/releases
install -d -m 0700 -o popi-harness -g popi-harness /var/lib/popi-harness /etc/popi-harness

node_version=22.22.3
node_archive="node-v${node_version}-linux-x64.tar.xz"
node_directory="/opt/popi-harness/node-v${node_version}-linux-x64"
if [[ ! -x "$node_directory/bin/node" ]]; then
  download_directory=$(mktemp -d)
  trap 'rm -rf "$download_directory"' EXIT
  curl --fail --silent --show-error --location "https://nodejs.org/dist/v${node_version}/${node_archive}" --output "$download_directory/$node_archive"
  curl --fail --silent --show-error --location "https://nodejs.org/dist/v${node_version}/SHASUMS256.txt" --output "$download_directory/SHASUMS256.txt"
  (cd "$download_directory" && awk -v archive="$node_archive" '$2 == archive' SHASUMS256.txt | sha256sum --check --strict)
  tar -xJf "$download_directory/$node_archive" -C /opt/popi-harness
fi
ln -sfn "$node_directory" /opt/popi-harness/node
test "$(/opt/popi-harness/node/bin/node --version)" = "v$node_version"
test -x /usr/bin/ffprobe
test -x /usr/bin/ffmpeg
test -x /bin/bash
command -v runuser >/dev/null
film_chrome=""
for candidate in /usr/bin/google-chrome-stable /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
  if [[ -x "$candidate" ]]; then
    film_chrome="$candidate"
    break
  fi
done
test -n "$film_chrome"
"$film_chrome" --version
bash "$(dirname "${BASH_SOURCE[0]}")/prepare-document-runtime.sh"
printf 'POPi runtime prerequisites ready\n'
