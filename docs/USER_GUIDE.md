# 完整使用说明

V1.1 支持 Windows 与 macOS。本文手动命令为 Windows；Mac 用户请阅读 [MACOS.md](MACOS.md)。原 Windows 发行版保留并标为 V1.0。

## 1. 安装包与源代码

给朋友使用时优先下载 Release 完整 ZIP：三个相关技能和本机高清处理程序都在包内。GitHub 的 `Code → Download ZIP` 是源代码包，未带大型运行时，首次使用 Real-ESRGAN 时需要联网下载官方引擎。两种方式都需要 Codex 的内置图片工具来执行 imagegen 补绘。

解压后根目录包含 `README.md`、`skills`、`scripts`、`docs` 和 `SHA256SUMS.txt`。保持目录结构，运行 `scripts/install.ps1`，下一轮 Codex 对话即可发现新技能。不要把整个压缩包直接放进一个技能文件夹而不解压。

## 2. 常用请求

```text
$change-wallpaper 把这张竖图扩展成横版壁纸，尽量保留主体，分别适配所有屏幕并设置。
```

```text
$change-wallpaper 图片中的花再繁密一些，保留墙面和光照。用 AI 做高清处理，然后应用到所有显示器。
```

```text
$change-wallpaper 我有一块横屏和一块竖屏，分别做合适的构图。先只生成文件给我看。
```

```text
$change-wallpaper 只生成适配显示器的高清壁纸，不更改当前桌面。
```

说明哪些对象必须保留、允许怎么变化，通常比反复强调“高清”更有帮助。默认保留原图主体和风格；花量、人物、建筑或风格的改变由本次请求决定。

## 3. 各阶段职责

imagegen 用来补绘画面、恢复合理视觉细节和调整构图。Real-ESRGAN 用神经网络将已有图片放大，并重建放大后的细节。Windows 脚本只做确定性的屏幕探测、裁边、缩小、设置和读回，不伪造 AI 处理结果。

当图片生成工具的实际输出没有达到提示词所写的尺寸时，必须按实际文件继续处理。4 倍 AI 放大表示宽、高各变为 4 倍；例如 1672×941 会生成 6688×3764，而不是只增加文件大小。

默认每屏壁纸是原生宽、高的 2 倍。共享 AI 母图经适当裁边后必须足够大，否则脚本直接拒绝后续普通放大。对于分辨率特别高或构图差异很大的屏幕，先增大或分别生成母图；无法达到时如实报告，不暗中降低要求。

## 4. 手动检查与执行

以下以当前用户的默认 Codex 目录为例；设置了 `CODEX_HOME` 的用户替换为对应目录：

```powershell
$codexDirectory = Join-Path $env:USERPROFILE '.codex'
$wallpaperSkill = Join-Path $codexDirectory 'skills\change-wallpaper'
$esrganSkill = Join-Path $codexDirectory 'skills\real-esrgan-skill'

# Read-only: list current monitor identities and native pixel rectangles.
& "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Inspect

# Run after imagegen has produced the edited composition.
& "$esrganSkill\scripts\upscale.ps1" -InputPath 'D:\Images\edited.png' -OutputPath 'D:\Images\ai-master.png'

# Create a NEW persistent output directory for this wallpaper.
& "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Prepare -MasterPath 'D:\Images\ai-master.png' -OutputDirectory 'D:\Wallpapers\spring' -PixelScale 2

# Apply only when the user has requested changing the wallpaper.
& "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Apply -ManifestPath 'D:\Wallpapers\spring\wallpaper-manifest.json'
```

显示器的 `Id` 是实际写入身份。`Index` 是本次 API 返回列表中的序号，不承诺等于 Windows 显示设置中的编号，也不等于“主屏”。混合 DPI 缩放、负坐标或主屏在不同位置，不会通过猜顺序把图片发到错误屏幕。

`Prepare` 不改变桌面；它保存每个屏幕的专用 PNG 和清单。`Apply` 再检查当前屏幕、图片尺寸和文件校验值，全部合格后才修改设置。中途换显示器、旋转屏幕或更改分辨率，应重新执行探测与准备。

## 5. 横屏、竖屏和超宽屏

比例接近且主体居中时可以共享母图，随后按各屏幕比例裁边。横屏与竖屏、超宽屏或边缘有重要主体时，应分别用 imagegen 补绘构图，再各自做 Real-ESRGAN 处理。不能把一个人的脸、花枝或文字强行裁掉来凑尺寸。

多母图源文件映射示例，键必须用 `Inspect` 返回的真实 `Id`，不要手写猜设备身份：

```powershell
$current = & "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Inspect | ConvertFrom-Json
$sources = @{}
$sources[$current.Monitors[0].Id] = 'D:\Images\landscape-ai-master.png'
$sources[$current.Monitors[1].Id] = 'D:\Images\portrait-ai-master.png'
$sources | ConvertTo-Json | Set-Content -LiteralPath 'D:\Images\sources.json' -Encoding UTF8
& "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Prepare -SourceMapPath 'D:\Images\sources.json' -OutputDirectory 'D:\Wallpapers\mixed'
```

以上两个数组序号只是示例。实际工作中先核对每个 `Id` 对应的宽、高、位置和用户要求，再确定映射。

## 6. 怎样判断清楚

先看完整画面，确定主体没有被拉伸或截断，再查看 100% 的花瓣、细枝、毛发、文字和纹理局部。检查有无白边、重影、重复纹理、塑料感或涂抹。最后按屏幕原生大小检查；高分辨率文件在缩小后仍应自然、清楚。

AI 会推断原图没有明确记录的细节。较多像素不等于较多真实信息，也不能保证把严重失焦或运动模糊完全修复。涉及文字时逐字检查；涉及人脸时检查身份和五官，不仅看锐度。

## 7. 恢复旧壁纸

应用前在壁纸输出目录创建 `wallpaper-backup-*.json`，其路径也会出现在命令结果中：

```powershell
& "$wallpaperSkill\scripts\wallpaper.ps1" -Mode Restore -ManifestPath 'D:\Wallpapers\spring\wallpaper-backup-EXAMPLE.json'
```

恢复原图路径、图片显示位置和原 JPEG 导入质量。旧图片必须仍然存在，连接的屏幕身份也必须匹配。备份不是完整 Windows 主题备份，不包含幻灯片播放列表、切换时序或旧图片文件本身。不要删除桌面当前引用的文件。

卸载技能时可以删除已安装的三个技能目录；系统自带 imagegen 应保留。仅删除技能不会删除已经生成的壁纸，也不会自动恢复旧背景。

## 8. 常见问题

| 现象 | 处理 |
|---|---|
| 没有 image_gen 工具 | 安装技能不能开通服务；使用支持内置图片工具的 Codex 环境。不得自动换用收费 API。 |
| Vulkan 初始化失败或没有可用 GPU | 核对显卡与驱动。无需 CUDA，但必须有可用 Vulkan；不把失败解释成图片问题。 |
| 显存不足 | 用同一新输出路径重试一次 `-TileSize 64`；若已有失败输出，先确认并删除本次失败文件或换新路径。 |
| 提示母图像素不足 | 提高 imagegen 母图尺寸或完成更合适的 AI 放大，不能只用普通缩放凑数字。 |
| 图片太平滑、像画 | 回看生成阶段与 Real-ESRGAN 输出，减少不必要的重复增强；不要换动漫模型来处理照片。 |
| 提示显示器身份或分辨率改变 | 重做 Inspect 和 Prepare；不要编辑旧清单伪造匹配。 |
| 提示文件被改动 | 重新准备清单并检查实际图片，不直接跳过 SHA-256 验证。 |
| 已有同名技能 | 默认不覆盖；确需更新时运行安装器 `-Update`，旧文件会先备份。 |
| PowerShell 报脚本执行限制 | 使用文档中的单次 `-ExecutionPolicy Bypass -File` 命令；不需要修改整机策略。 |

## 9. 适用范围与已验证范围

Windows 路径面向 Windows 10/11 x64，按实际活动屏幕动态工作，尚未逐一测试所有显卡、显示器及远程桌面。V1.1 新增 macOS 原生路径，已在 Intel 与 arm64 托管 macOS 测试机验证桌面 API 和真实 GPU 小图推理；实体 Retina 多屏视觉效果仍须在目标电脑检查。详见 [VALIDATION.md](VALIDATION.md)。Linux 自动壁纸控制不在本包范围内。
