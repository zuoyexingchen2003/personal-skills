#!/usr/bin/env bash
# Install real-esrgan-skill into ~/.claude/skills/ (Claude Code user skills).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/.claude/skills/real-esrgan-skill"

[ -f "$SRC/SKILL.md" ] || { echo "SKILL.md not found in $SRC — run this from the repo root" >&2; exit 1; }

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
mkdir -p "$DEST/scripts"
cp "$SRC/SKILL.md" "$DEST/SKILL.md"
cp "$SRC"/scripts/* "$DEST/scripts/"
chmod +x "$DEST"/scripts/* 2>/dev/null || true

echo "[ok] installed to $DEST"
echo "[next] restart your Claude Code session (or open a new one), then say:"
echo "       帮我把 xxx.mp4 超分到 4 倍"
