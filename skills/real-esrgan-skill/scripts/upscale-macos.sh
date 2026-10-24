#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'This entry point requires macOS.' >&2; exit 1; }
[[ $# -ge 2 ]] || { echo 'Usage: bash upscale-macos.sh INPUT OUTPUT.png [TILE_SIZE]' >&2; exit 2; }
input="$1"; output="$2"; tile="${3:-128}"
[[ -f "$input" && ! -e "$output" && "$output" == *.png ]] || { echo 'Input must exist; output must be a new PNG path.' >&2; exit 1; }
[[ "$tile" =~ ^[0-9]+$ && "$tile" -ge 32 && "$tile" -le 1024 ]] || { echo 'Tile size must be 32..1024.' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
engine_dir="$script_dir/../runtime/macos-universal"
exe="$engine_dir/realesrgan-ncnn-vulkan"
if [[ ! -f "$exe" ]]; then
  archive="$(mktemp -t realesrgan-macos).zip"
  trap 'rm -f "$archive"' EXIT
  /usr/bin/curl --fail --location --connect-timeout 20 --max-time 300 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip' -o "$archive"
  actual="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
  [[ "$actual" == e0ad05580abfeb25f8d8fb55aaf7bedf552c375b5b4d9bd3c8d59764d2cc333a ]] || { echo 'Official macOS engine archive hash mismatch.' >&2; exit 1; }
  mkdir -p "$engine_dir"
  /usr/bin/ditto -xk "$archive" "$engine_dir"
fi
chmod u+x "$exe"
[[ -f "$engine_dir/models/realesrgan-x4plus.bin" ]] || { echo 'Photo model is missing.' >&2; exit 1; }
dimensions() { /usr/bin/sips -g pixelWidth -g pixelHeight "$1" | /usr/bin/awk '$1=="pixelWidth:" {w=$2} $1=="pixelHeight:" {h=$2} END {if(w>0 && h>0) print w,h; else exit 1}'; }
read -r width height <<< "$(dimensions "$input")"
mkdir -p "$(dirname "$output")"
if ! "$exe" -i "$input" -o "$output" -m "$engine_dir/models" -n realesrgan-x4plus -s 4 -t "$tile" -f png; then
  echo 'Real-ESRGAN failed. Check Metal/MoltenVK GPU availability. If macOS blocks the unsigned executable, verify the package hash and approve this individual program in System Settings; this script does not remove quarantine or disable Gatekeeper.' >&2
  exit 1
fi
read -r result_width result_height <<< "$(dimensions "$output")"
[[ "$result_width" -eq $((width*4)) && "$result_height" -eq $((height*4)) ]] || { echo 'AI output pixel dimensions failed verification.' >&2; exit 1; }
printf 'AI upscale verified: %sx%s -> %sx%s (realesrgan-x4plus, 4x)\n' "$width" "$height" "$result_width" "$result_height"
