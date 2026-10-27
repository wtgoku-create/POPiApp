#!/usr/bin/env bash
set -euo pipefail

# Installing the browser is explicit; the default command only checks tools.
install_browser=false
case "${1:-}" in
  "") ;;
  --install-browser) install_browser=true ;;
  *) printf 'Usage: prepare-film-runtime.sh [--install-browser]\n' >&2; exit 2 ;;
esac

find_browser() {
  local candidate
  for candidate in /usr/bin/google-chrome-stable /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! film_browser=$(find_browser); then
  if [[ "$install_browser" != true ]]; then
    printf 'Chrome/Chromium is missing; film creation remains unavailable. Run with --install-browser on the Linux server to prepare it.\n' >&2
    exit 3
  fi
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]]
  command -v apt-get >/dev/null
  command -v curl >/dev/null
  command -v gpg >/dev/null
  browser_key_directory=$(mktemp -d)
  trap 'rm -rf "$browser_key_directory"' EXIT
  curl --fail --silent --show-error --location --proto '=https' \
    https://dl.google.com/linux/linux_signing_key.pub \
    --output "$browser_key_directory/google.pub"
  gpg --show-keys --with-colons "$browser_key_directory/google.pub" 2>/dev/null | \
    awk -F: '$1 == "fpr" && $10 == "EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796" { found = 1 } END { exit !found }'
  gpg --batch --yes --dearmor --output "$browser_key_directory/google.gpg" "$browser_key_directory/google.pub"
  install -m 0644 "$browser_key_directory/google.gpg" /usr/share/keyrings/popi-google-chrome.gpg
  # This dedicated source never changes unrelated APT sources or trust settings.
  printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/popi-google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main\n' \
    > /etc/apt/sources.list.d/popi-google-chrome.list
  # Minimal hosts may have no distro indexes cached for Chrome dependencies.
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --yes google-chrome-stable
  film_browser=$(find_browser)
fi

test -x /usr/bin/ffmpeg
test -x /usr/bin/ffprobe
"$film_browser" --version
printf 'Film tools present. Run the renderer validation as popi-harness with normal browser sandboxing before enabling styles.\n'
