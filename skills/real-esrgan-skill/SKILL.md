---
name: real-esrgan-skill
description: Upscale images and videos 2x/4x with Real-ESRGAN super resolution. Use when the user asks to 超分 / 放大分辨率 / 提升清晰度 / upscale / enhance resolution / upscale video of an image or video file.
---

# Real-ESRGAN Upscale

## macOS V1.1 entry point

For macOS still images, use `bash "$SKILL_DIR/scripts/upscale-macos.sh" INPUT OUTPUT.png [TILE_SIZE]`. The complete Mac ZIP includes the official Intel/Apple Silicon universal ncnn/Vulkan engine. This path runs `realesrgan-x4plus` at real 4x scale and verifies pixel dimensions with the system `sips` utility. It needs working Metal/MoltenVK GPU support, not Python, ffmpeg, CUDA or a paid API. Default tile size is 128; retry once with 64 only for memory trouble. Preserve the input and use a new output path.

Source-only installations download only the official Mac ZIP and verify SHA-256 `e0ad05580abfeb25f8d8fb55aaf7bedf552c375b5b4d9bd3c8d59764d2cc333a`. Do not disable Gatekeeper or strip quarantine automatically; if macOS blocks an unsigned executable, explain the specific system approval needed. This supersedes the old global-disable suggestion in the upstream runtime README.

## Windows portable entry point (personal-skills addition)

For Windows still-image upscaling, prefer the bundled PowerShell entry point:

```powershell
& "$SKILL_DIR/scripts/upscale.ps1" -InputPath $inputImage -OutputPath $outputPng
```

This runs the official Windows x64 ncnn/Vulkan executable with `realesrgan-x4plus` at actual 4x scale, checks the resulting pixel dimensions, and produces a new lossless PNG. It needs a Vulkan-capable GPU and its working driver. Python, Git Bash, CUDA, PyTorch, ffmpeg and API keys are not required for this image path. The complete release package includes the portable engine and models in `runtime/windows-x64`; source-only installation downloads the official release and checks a pinned SHA-256 on first use. It never uses an unofficial mirror.

`-EngineDirectory` selects an existing official runtime. If GPU memory is insufficient, retry once with `-TileSize 64`. Do not label a failed inference or ordinary resize as successful AI enhancement. Preserve the input and refuse to overwrite an existing output.

The original shell workflow below remains available for other platforms and video. Those paths are upstream instructions, not evidence of Windows wallpaper support on macOS/Linux. This distribution adds `scripts/upscale.ps1`; the original skill is by pangpang778 under its included MIT license.

Upscale an image or video with Real-ESRGAN (ncnn-vulkan build). One engine, two modes.

## Quick start

Run the pipeline script — do NOT hand-roll ffmpeg commands:

```bash
bash "$SKILL_DIR/scripts/upscale.sh" <input-file> [-s 2|3|4] [-n MODEL] [-o OUTPUT]
```

- `-s` scale factor, default 4
- `-n` model: `realesrgan-x4plus` (default, real-world photos/video), `realesrgan-x4plus-anime` (anime), `realesr-general-x4v3` (small & fast general)
- `-o` output path; default: `<input>_x<s>.<ext>` next to input

Determine `$SKILL_DIR` from where this SKILL.md lives.

The script handles everything below automatically. Read on only if it fails.

## What the script does

1. **Engine setup** — needs `realesrgan-ncnn-vulkan` binary (cached in `~/.real-esrgan-skill/bin/`). On first run it downloads the official build for the platform from https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/ :
   - Windows: `realesrgan-ncnn-vulkan-20220424-windows.zip`
   - macOS: `realesrgan-ncnn-vulkan-20220424-macos.zip` (untested)
   - Linux: `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` (untested)
   If GitHub is unreachable or too slow (common in China), retry with the mirror prefix `https://gh-proxy.com/` prepended to the URL.
2. **ffmpeg check** — video mode needs ffmpeg. If missing, STOP and show the user the one-liner for their platform, ask them to confirm before installing:
   - Windows: `winget install Gyan.FFmpeg`
   - macOS: `brew install ffmpeg`
   - Linux: `sudo apt install ffmpeg`
   Never install silently.
3. **Image mode** (`.png/.jpg/.jpeg/.webp`): single exe call, output PNG.
4. **Video mode**: extract frames (`ffmpeg -vsync 0`, PNG) → upscale every frame → reassemble with `libx264 -crf 18 -pix_fmt yuv420p`, copying the original audio track. Frames live in a `mktemp -d` dir, deleted at the end.

## Notes and failure modes

- Requires a Vulkan-capable GPU (NVIDIA/AMD/Intel). No GPU → the exe errors out; tell the user this is a hard requirement.
- Out of GPU memory on huge frames → retry adding `-t 128` (tile size) by calling the exe directly.
- The engine upscales by integer factor from input resolution. A 480p source at 4x gives 1920p — the model cannot invent pixels that were never captured.
- Videos: ~2.5s/frame on an RTX 4060 laptop. Estimate `frame_count × 2.5s` and tell the user before starting long videos.
- **Verify after reassembly**: compare output frame count (`ffprobe -count_frames ... nb_read_frames`) against the input's. A shortfall means frames were corrupted mid-pipeline — classic cause is a full disk (frame PNGs get silently truncated). Free space, wipe the temp frames, and rerun; put temp frames on a drive with enough headroom (a 1080p-source 4K upscale needs ~5-10MB per frame).
- macOS/Linux paths are documented but untested; if they fail, debug from the exe's own error output.
- Text rendered inside AI-generated video (banners, subtitles) may come out garbled — the model redraws glyphs, it does not read them.
