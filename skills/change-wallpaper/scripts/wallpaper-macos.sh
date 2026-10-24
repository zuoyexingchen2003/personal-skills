#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'This entry point requires macOS.' >&2; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
binary="$script_dir/../runtime/macos-universal/wallpaper-macos"
if [[ -f "$binary" ]]; then
  chmod u+x "$binary"
  exec "$binary" "$@"
fi
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo 'Source-only installation requires Apple Command Line Tools, or use the complete V1.1 macOS ZIP with its prebuilt universal helper.' >&2
  exit 1
fi
exec /usr/bin/xcrun swift "$script_dir/wallpaper-macos.swift" "$@"
