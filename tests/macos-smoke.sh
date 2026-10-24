#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/change-wallpaper-macos-test"
mkdir -p "$test_dir/artifact"
source_file="$repo_root/skills/change-wallpaper/scripts/wallpaper-macos.swift"
for arch in arm64 x86_64; do
  /usr/bin/xcrun swiftc -swift-version 5 -O -target "$arch-apple-macosx12.0" "$source_file" -o "$test_dir/wallpaper-$arch"
done
/usr/bin/lipo -create "$test_dir/wallpaper-arm64" "$test_dir/wallpaper-x86_64" -output "$test_dir/artifact/wallpaper-macos"
tool="$test_dir/artifact/wallpaper-macos"
"$tool" self-test --output "$test_dir/self-test" > "$test_dir/artifact/geometry.json"
for script in "$repo_root/scripts/install.sh" "$repo_root/skills/change-wallpaper/scripts/wallpaper-macos.sh" "$repo_root/skills/real-esrgan-skill/scripts/upscale-macos.sh"; do /bin/bash -n "$script"; done
bash "$repo_root/scripts/install.sh" --skills-root "$test_dir/install with spaces/skills"
[[ -f "$test_dir/install with spaces/skills/change-wallpaper/SKILL.md" && -f "$test_dir/install with spaces/skills/imagegen/SKILL.md" && -f "$test_dir/install with spaces/skills/real-esrgan-skill/SKILL.md" ]]
echo 'keep me' > "$test_dir/install with spaces/skills/change-wallpaper/existing-marker.txt"
bash "$repo_root/scripts/install.sh" --skills-root "$test_dir/install with spaces/skills"
[[ -f "$test_dir/install with spaces/skills/change-wallpaper/existing-marker.txt" ]]
bash "$repo_root/scripts/install.sh" --skills-root "$test_dir/install with spaces/skills" --update
[[ ! -e "$test_dir/install with spaces/skills/change-wallpaper/existing-marker.txt" ]]
[[ -n "$(find "$test_dir/install with spaces/skill-backups" -name existing-marker.txt -print)" ]]
desktop_status='NO_GUI_SESSION'
if "$tool" inspect > "$test_dir/artifact/inspect.json" 2> "$test_dir/artifact/inspect-error.txt"; then
  desktop_status='INSPECT_PASS_NO_STATIC_BACKUP'
  if python3 -c 'import json,os,sys; d=json.load(open(sys.argv[1]));sys.exit(0 if all(x.get("Image") and os.path.isfile(x["Image"]) for x in d["Monitors"]) else 1)' "$test_dir/artifact/inspect.json"; then
    "$tool" desktop-test --output "$test_dir/desktop" > "$test_dir/artifact/desktop.json"
    desktop_status='APPLY_RESTORE_PASS'
  fi
fi
curl --fail --location --max-time 300 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip' -o "$test_dir/engine.zip"
echo 'e0ad05580abfeb25f8d8fb55aaf7bedf552c375b5b4d9bd3c8d59764d2cc333a  engine.zip' | (cd "$test_dir" && shasum -a 256 -c -)
engine_dir="$test_dir/install with spaces/skills/real-esrgan-skill/runtime/macos-universal"
mkdir -p "$engine_dir"
ditto -xk "$test_dir/engine.zip" "$engine_dir"
chmod u+x "$engine_dir/realesrgan-ncnn-vulkan"
"$engine_dir/realesrgan-ncnn-vulkan" -h > "$test_dir/artifact/engine-help.txt" 2>&1 || help_status=$?
grep -q 'Usage:' "$test_dir/artifact/engine-help.txt"
gpu_status='UNAVAILABLE'
if bash "$test_dir/install with spaces/skills/real-esrgan-skill/scripts/upscale-macos.sh" "$test_dir/self-test/gpu-input.png" "$test_dir/gpu-output.png" > "$test_dir/artifact/gpu.log" 2>&1; then gpu_status='INFERENCE_4X_PASS'; fi
/usr/bin/shasum -a 256 "$source_file" | awk '{print $1}' > "$test_dir/artifact/source.sha256"
python3 - "$desktop_status" "$gpu_status" "$test_dir/artifact/report.json" <<'PY'
import json,platform,sys
report={"Platform":platform.platform(),"Architecture":platform.machine(),"UniversalCompile":"PASS","Geometry":"PASS","Installer":"PASS","ExistingPreservedAndUpdateBackedUp":"PASS","NativeDesktop":sys.argv[1],"OfficialEngineLoad":"PASS","GPU":sys.argv[2]}
with open(sys.argv[3],"w") as f: json.dump(report,f,indent=2)
print(json.dumps(report,indent=2))
PY
