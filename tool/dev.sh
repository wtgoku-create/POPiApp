#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

usage() {
  printf '%s\n' \
    'Usage: tool/dev.sh [web-remote|web-local|harness|macos|macos-local|demo|app|setup|doctor|test|build-web|build-web-local|build-demo-web] [arguments]' \
    '' \
    'Commands:' \
    '  web-remote Open the deployed Web Harness backed by the test server (default).' \
    '             This shows deployed UI; local source changes require a build and deploy.' \
    '  web-local  Run the local Web Harness on 127.0.0.1:7357 against the local Agent.' \
    '  harness    Alias for web-local.' \
    '  macos      Run the native macOS POPi app against the same server as phones.' \
    '  macos-local  Run the native macOS POPi app against the local Agent.' \
    '  demo       Run the explicit offline demo on 127.0.0.1:7357.' \
    '  app        Run the main app entry point on 127.0.0.1:7357.' \
    '  setup      Run flutter pub get, then flutter gen-l10n.' \
    '  doctor     Run flutter doctor -v.' \
    '  test       Run analysis, then tests with the selected environment.' \
    '  build-web  Build the remote-server Harness entry point for web.' \
    '  build-web-local  Build the local-Agent Harness entry point for web.' \
    '  build-demo-web  Build the explicit offline demo for web.' \
    '' \
    'Environment:' \
    '  FLUTTER_ROOT   Preferred Flutter SDK directory.' \
    '  POPI_ENV_FILE  Environment name or JSON path (overrides a command default).'
}

find_flutter() {
  local candidate=''

  if [[ -n "${FLUTTER_ROOT:-}" ]]; then
    candidate="${FLUTTER_ROOT%/}/bin/flutter"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if command -v flutter >/dev/null 2>&1; then
    candidate="$(command -v flutter)"
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="${HOME:-}/SDK/flutter/bin/flutter"
  if [[ -n "${HOME:-}" && -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

command_name="${1:-web-remote}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$command_name" in
  help|-h|--help)
    usage
    exit 0
    ;;
  demo|web-remote|web-local|harness|macos|macos-local|app|setup|doctor|test|build-web|build-web-local|build-demo-web)
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command_name" >&2
    usage >&2
    exit 64
    ;;
esac

case "$command_name" in
  web-remote|macos|build-web)
    env_file="${POPI_ENV_FILE:-harness_remote}"
    ;;
  web-local|harness|macos-local|build-web-local)
    env_file="${POPI_ENV_FILE:-harness}"
    ;;
  *)
    env_file="${POPI_ENV_FILE:-development}"
    ;;
esac

resolve_env_file() {
  if [[ "$env_file" == *.json ]]; then
    printf '%s\n' "$env_file"
  else
    printf '%s\n' "$repo_root/config/env/$env_file.json"
  fi
}

open_remote_web() {
  local config_file
  local public_url
  config_file="$(resolve_env_file)"
  public_url="$(python3 - "$config_file" <<'PY'
import json
import sys
from urllib.parse import urlsplit

with open(sys.argv[1], encoding='utf-8') as source:
    config = json.load(source)
value = config.get('AGENT_API_ORIGIN') or config.get('AGENT_API_BASE_URL')
url = urlsplit(value)
if (url.scheme != 'https' or not url.hostname or url.username is not None
        or url.password is not None or url.path not in ('', '/')
        or url.query or url.fragment):
    raise SystemExit('Remote Web Harness requires a clean HTTPS origin')
print(f'{url.scheme}://{url.netloc}/')
PY
)"

  printf 'Opening deployed Web Harness: %s\n' "$public_url"
  if command -v open >/dev/null 2>&1; then
    open "$public_url"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$public_url"
  else
    printf 'Open this URL in a browser: %s\n' "$public_url"
  fi
}

if [[ "$command_name" == 'web-remote' ]]; then
  cd "$repo_root"
  open_remote_web
  exit 0
fi

if ! flutter_bin="$(find_flutter)"; then
  printf '%s\n' \
    'Flutter was not found. Set FLUTTER_ROOT, add flutter to PATH, or install it at ~/SDK/flutter.' >&2
  exit 127
fi

flutter_bin_dir="$(cd "$(dirname "$flutter_bin")" && pwd)"
flutter_bin="$flutter_bin_dir/$(basename "$flutter_bin")"
export PATH="$flutter_bin_dir:$PATH"

has_run_option() {
  local short_option="$1"
  local long_option="$2"
  shift 2

  local argument
  for argument in "$@"; do
    if [[ "$argument" == '--' ]]; then
      break
    fi
    case "$argument" in
      "$short_option"|"$short_option"?*|"$long_option"|"$long_option"=*)
        return 0
        ;;
    esac
  done
  return 1
}

run_entrypoint() {
  local target="$1"
  shift

  local -a run_args=('-t' "$target")
  if ! has_run_option '-d' '--device-id' "$@"; then
    run_args+=('-d' 'web-server')
    # Generic browsers use hot restart; explicit Chrome/native devices retain hot reload.
    if ! has_run_option \
      '--web-experimental-hot-reload' \
      '--no-web-experimental-hot-reload' \
      "$@"; then
      run_args+=('--no-web-experimental-hot-reload')
    fi
    if ! has_run_option '--web-hostname' '--web-hostname' "$@"; then
      run_args+=('--web-hostname' '127.0.0.1')
    fi
    if ! has_run_option '--web-port' '--web-port' "$@"; then
      run_args+=('--web-port' '7357')
    fi
  fi
  run_args+=("$@")

  cd "$repo_root"
  dart run tool/flutter_env.dart "$env_file" run "${run_args[@]}"
}

case "$command_name" in
  demo)
    run_entrypoint 'lib/main_demo.dart' "$@"
    ;;
  web-local|harness)
    run_entrypoint 'lib/main_harness.dart' "$@"
    ;;
  macos|macos-local)
    run_entrypoint 'lib/main_harness.dart' -d macos "$@"
    ;;
  app)
    run_entrypoint 'lib/main.dart' "$@"
    ;;
  setup)
    cd "$repo_root"
    "$flutter_bin" pub get "$@"
    "$flutter_bin" gen-l10n
    ;;
  doctor)
    cd "$repo_root"
    "$flutter_bin" doctor -v "$@"
    ;;
  test)
    cd "$repo_root"
    "$flutter_bin" analyze
    exec dart run tool/flutter_env.dart "$env_file" test "$@"
    ;;
  build-web|build-web-local)
    cd "$repo_root"
    dart run tool/flutter_env.dart "$env_file" build web \
      -t lib/main_harness.dart "$@"
    ;;
  build-demo-web)
    cd "$repo_root"
    dart run tool/flutter_env.dart "$env_file" build web \
      -t lib/main_demo.dart "$@"
    ;;
esac
