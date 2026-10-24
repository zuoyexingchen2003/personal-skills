#!/usr/bin/env bash
# Real-ESRGAN upscale pipeline: image or video -> 2x/3x/4x.
# Usage: upscale.sh INPUT [-s 2|3|4] [-n MODEL] [-o OUTPUT]
set -euo pipefail

usage() { echo "usage: $0 INPUT [-s 2|3|4] [-n realesrgan-x4plus|realesrgan-x4plus-anime|realesr-general-x4v3] [-o OUTPUT]" >&2; exit 1; }

[ $# -ge 1 ] || usage
INPUT=""
SCALE=4
MODEL="realesrgan-x4plus"
OUTPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -s) SCALE="$2"; shift 2 ;;
    -n) MODEL="$2"; shift 2 ;;
    -o) OUTPUT="$2"; shift 2 ;;
    -*) usage ;;
    *) INPUT="$1"; shift ;;
  esac
done
[ -n "$INPUT" ] && [ -f "$INPUT" ] || { echo "input not found: $INPUT" >&2; exit 1; }

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows"; SUFFIX=".exe" ;;
  Darwin)               PLATFORM="macos";   SUFFIX="" ;;
  *)                    PLATFORM="ubuntu";  SUFFIX="" ;;
esac

ENGINE_DIR="${HOME}/.real-esrgan-skill/bin"
EXE="$ENGINE_DIR/realesrgan-ncnn-vulkan$SUFFIX"

if [ ! -x "$EXE" ]; then
  URL="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-${PLATFORM}.zip"
  echo "[setup] downloading Real-ESRGAN engine for $PLATFORM ..."
  mkdir -p "$ENGINE_DIR"
  TMPZIP="$(mktemp -u).zip"
  if ! curl -fL --connect-timeout 15 -o "$TMPZIP" "$URL" 2>/dev/null; then
    echo "[setup] github failed, retrying via gh-proxy mirror ..."
    curl -fL --connect-timeout 15 -o "$TMPZIP" "https://gh-proxy.com/$URL"
  fi
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "$TMPZIP" -d "$ENGINE_DIR"
  else
    python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMPZIP" "$ENGINE_DIR"
  fi
  rm -f "$TMPZIP"
  # flatten: some zips nest the binary one level down
  if [ ! -x "$EXE" ]; then
    FOUND="$(find "$ENGINE_DIR" -name "realesrgan-ncnn-vulkan$SUFFIX" -type f | head -1)"
    [ -n "$FOUND" ] && cp -f "$FOUND" "$EXE"
  fi
  [ "$PLATFORM" != "windows" ] && chmod +x "$EXE"
  [ -x "$EXE" ] || { echo "[setup] engine download failed" >&2; exit 1; }
fi

if [ -z "$OUTPUT" ]; then
  DIR="$(dirname "$INPUT")"
  STEM="$(basename "$INPUT")"
  STEM="${STEM%.*}"
  case "$INPUT" in
    *.png|*.jpg|*.jpeg|*.webp) OUTPUT="$DIR/${STEM}_x${SCALE}.png" ;;
    *) OUTPUT="$DIR/${STEM}_x${SCALE}.mp4" ;;
  esac
fi

case "$INPUT" in
  *.png|*.jpg|*.jpeg|*.webp)
    echo "[upscale] image x$SCALE ($MODEL)"
    mkdir -p "$(dirname "$OUTPUT")"
    "$EXE" -i "$INPUT" -o "$OUTPUT" -n "$MODEL" -s "$SCALE" -f png
    ;;
  *)
    command -v ffmpeg >/dev/null 2>&1 || {
      echo "[stop] ffmpeg not found. Install it first:" >&2
      case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "  winget install Gyan.FFmpeg" >&2 ;;
        Darwin)               echo "  brew install ffmpeg" >&2 ;;
        *)                    echo "  sudo apt install ffmpeg" >&2 ;;
      esac
      exit 2
    }
    FPS="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT")"
    FRAMES="$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$INPUT")"
    echo "[upscale] video x$SCALE ($MODEL): $FRAMES frames @ ${FPS}fps"
    echo "[upscale] estimate: ~$(( FRAMES * 25 / 10 ))s on an RTX 4060-class GPU"
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT
    mkdir "$TMPDIR/in" "$TMPDIR/out"
    ffmpeg -y -v error -i "$INPUT" -vsync 0 "$TMPDIR/in/%08d.png"
    "$EXE" -i "$TMPDIR/in" -o "$TMPDIR/out" -n "$MODEL" -s "$SCALE" -f png
    mkdir -p "$(dirname "$OUTPUT")"
    ffmpeg -y -v error -framerate "$FPS" -i "$TMPDIR/out/%08d.png" -i "$INPUT" \
      -map 0:v -map 1:a? -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a copy "$OUTPUT"
    ;;
esac

echo "[done] $OUTPUT"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT" \
  | awk -F, '{print "[info] output resolution: " $1 "x" $2}'
