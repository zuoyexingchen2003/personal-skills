#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Use install.ps1 on Windows. This installer targets macOS.' >&2; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(dirname -- "$script_dir")"
skills_root="${CODEX_HOME:-$HOME/.codex}/skills"
update=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-root) [[ $# -ge 2 ]] || exit 2; skills_root="$2"; shift 2 ;;
    --update) update=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [[ -f "$repo_root/SHA256SUMS.txt" ]]; then
  (cd "$repo_root" && /usr/bin/shasum -a 256 -c SHA256SUMS.txt >/dev/null)
fi
mkdir -p "$skills_root"
skills_root="$(cd "$skills_root" && pwd -P)"
for name in imagegen real-esrgan-skill change-wallpaper; do
  source_dir="$repo_root/skills/$name"
  target="$skills_root/$name"
  [[ -f "$source_dir/SKILL.md" ]] || { echo "Incomplete package: $name" >&2; exit 1; }
  if [[ "$name" == imagegen && -f "$skills_root/.system/imagegen/SKILL.md" ]]; then
    echo 'imagegen: using the existing built-in skill'; continue
  fi
  [[ ! -L "$target" ]] || { echo "Refusing to replace a symlink: $target" >&2; exit 1; }
  if [[ -e "$target" ]]; then
    if [[ "$update" == 0 ]]; then echo "$name: preserved existing installation; use --update to back up and replace"; continue; fi
    backup="$(dirname "$skills_root")/skill-backups/$(/usr/bin/uuidgen)/$name"
    mkdir -p "$(dirname "$backup")"
    mv "$target" "$backup"
  fi
  cp -R "$source_dir" "$target"
  for executable in "$target/runtime/macos-universal/wallpaper-macos" "$target/runtime/macos-universal/realesrgan-ncnn-vulkan"; do
    if [[ -f "$executable" ]]; then chmod u+x "$executable"; fi
  done
  echo "$name: installed in $target"
done
echo 'Available in the next Codex turn. Installing skills does not enable imagegen service access.'
