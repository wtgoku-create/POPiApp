#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

usage() {
  printf '%s\n' \
    'Usage: tool/dev.sh [harness|macos|demo|app|setup|doctor|test|build-web|build-demo-web] [arguments]' \
    '' \
    'Commands:' \
    '  harness    Run the shared Harness UI on 127.0.0.1:7357 (default).' \
    '  macos      Run the same Harness UI as the native macOS POPi app.' \
    '  demo       Run the explicit offline demo on 127.0.0.1:7357.' \
    '  app        Run the main app entry point on 127.0.0.1:7357.' \
    '  setup      Run flutter pub get, then flutter gen-l10n.' \
    '  doctor     Run flutter doctor -v.' \
    '  test       Run analysis, then tests with the selected environment.' \
    '  build-web  Build the shared Harness entry point for web.' \
    '  build-demo-web  Build the explicit offline demo for web.' \
    '' \
    'Environment:' \
    '  FLUTTER_ROOT   Preferred Flutter SDK directory.' \
    '  POPI_ENV_FILE  Environment name or JSON path (Harness commands default to harness).'
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

command_name="${1:-harness}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$command_name" in
  help|-h|--help)
    usage
    exit 0
    ;;
  demo|harness|macos|app|setup|doctor|test|build-web|build-demo-web)
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command_name" >&2
    usage >&2
    exit 64
    ;;
esac

if ! flutter_bin="$(find_flutter)"; then
  printf '%s\n' \
    'Flutter was not found. Set FLUTTER_ROOT, add flutter to PATH, or install it at ~/SDK/flutter.' >&2
  exit 127
fi

flutter_bin_dir="$(cd "$(dirname "$flutter_bin")" && pwd)"
flutter_bin="$flutter_bin_dir/$(basename "$flutter_bin")"
export PATH="$flutter_bin_dir:$PATH"

if [[ "$command_name" == 'harness' || "$command_name" == 'macos' || "$command_name" == 'build-web' ]]; then
  env_file="${POPI_ENV_FILE:-harness}"
else
  env_file="${POPI_ENV_FILE:-development}"
fi

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
  harness)
    run_entrypoint 'lib/main_harness.dart' "$@"
    ;;
  macos)
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
  build-web)
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
