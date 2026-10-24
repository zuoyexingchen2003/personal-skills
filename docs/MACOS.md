# macOS 使用说明 — V1.1

## 安装

下载 `personal-skills-change-wallpaper-V1.1-macos.zip`，解压后在终端进入 `personal-skills` 文件夹：

```bash
bash scripts/install.sh
```

完整包包含 change-wallpaper、imagegen、real-esrgan-skill 三个技能、官方 Real-ESRGAN universal 引擎与模型，以及预编译的屏幕工具。适用 macOS 12+，Intel 与 Apple Silicon 使用同一包。不需要 Python、Homebrew、ffmpeg、CUDA 或 Xcode；需要带内置 image_gen 工具的 Codex 和可用 Metal/MoltenVK GPU。

安装器先校验包内 SHA-256，默认安装到 `${CODEX_HOME:-$HOME/.codex}/skills`，并为包内原生工具添加执行权限。若你的 Codex 从其他目录发现技能，使用 `--skills-root /actual/skills/path`。已有内置 imagegen 会复用，同名个人技能默认保留。更新命令：

```bash
bash scripts/install.sh --update
```

更新前把旧技能移到 `skill-backups`。下一轮对话调用 `$change-wallpaper` 并附图；仅制作文件时明确说“只生成，不设置”。

## Retina 与像素

“看起来像 1440×900”一般指界面点数，不能直接当壁纸像素。工具分别报告逻辑点数、backing scale、当前模式/渲染像素，并按实际方向处理，不固定假定 Retina 一律为 2 倍。默认目标宽、高各为当前像素的 2 倍；母图不足时拒绝普通插值放大。

“更多空间”可能先渲染到比面板更高的像素再缩小；这里明确报告当前渲染需求，不声称读取了面板出厂规格。显示器 UUID 用于匹配，不把“列表第一个”当主屏。横竖混用或主体靠边时，先分别补绘构图，再做 AI 放大，不能强行裁掉主体。

## 手动执行

```bash
skills_root="${CODEX_HOME:-$HOME/.codex}/skills"
wallpaper_skill="$skills_root/change-wallpaper"
esrgan_skill="$skills_root/real-esrgan-skill"
bash "$wallpaper_skill/scripts/wallpaper-macos.sh" inspect

# imagegen 补绘完成后，实际执行 4 倍 AI 放大。
bash "$esrgan_skill/scripts/upscale-macos.sh" "/path/edited.png" "/path/ai-master.png"

# 新目录持久保存桌面引用的图片。
bash "$wallpaper_skill/scripts/wallpaper-macos.sh" prepare \
  --master "/path/ai-master.png" --output "/path/wallpapers/new" --pixel-scale 2

# 视觉检查完成且用户要求更换桌面后执行。
bash "$wallpaper_skill/scripts/wallpaper-macos.sh" apply \
  --manifest "/path/wallpapers/new/wallpaper-manifest.json"
```

多母图使用 `--sources sources.json`，JSON 的键为 `inspect` 返回的 UUID，值为对应 AI 母图的绝对路径。可同时传 `--master` 作为未映射屏幕的默认来源。检查完整画面，以及花瓣、毛发、文字、枝条和纹理的局部，不用像素数字代替视觉质量。

## 设置与恢复

主线程使用 `NSWorkspace.setDesktopImageURL` 按 UUID 逐屏设置。应用前核对身份、尺寸、方向和文件校验值，备份旧静态图片 URL 与缩放/裁边/填充色选项；设置后最多等待 5 秒的系统刷新并读回路径。失败时尝试恢复，恢复失败明确报告。

```bash
bash "$wallpaper_skill/scripts/wallpaper-macos.sh" restore \
  --manifest "/path/wallpapers/new/wallpaper-backup-UUID.json"
```

只处理当前登录桌面会话的各屏幕，不承诺更改所有其他 Space、锁屏、Stage Manager 工作空间或完整动态/视频壁纸。备份不复制旧图片，旧静态图片文件必须仍然存在。

## macOS 程序批准

本包 helper 和上游引擎没有 Apple 公证。系统可能要求批准单个程序；先核对 Release 的 `.sha256` 与包内清单，再按系统提示在“系统设置 → 隐私与安全性”批准相应程序。流程不会删除 quarantine 或关闭 Gatekeeper，上游 README 中旧的全局关闭建议不属于本包流程。

源码安装没有预编译 helper 时，需要 Apple Command Line Tools，缺少会提示使用完整包或自行安装，不自动安装系统软件。Real-ESRGAN 缺少时只从官方 GitHub 下载并校验固定 SHA-256，不使用不明镜像。

## 实测范围

[双架构 CI](https://github.com/zuoyexingchen2003/personal-skills/actions/runs/40083427744) 实际测试 Intel macOS 15.7.9 和 arm64 macOS 26.6.2：universal 编译、横竖图像处理、低像素拒绝、安装/更新备份、原生屏幕探测、桌面设置与恢复、篡改文件拒绝，以及真实 GPU 64×64→256×256 推理均通过。

这些是托管 macOS 测试会话。实体 Retina、多块物理屏幕、大幅照片的完整 Mac 视觉流程尚未逐一实测。最低 macOS 12 是编译目标，不等于每个 OS 版本都已实测。详见 [VALIDATION.md](VALIDATION.md)。
