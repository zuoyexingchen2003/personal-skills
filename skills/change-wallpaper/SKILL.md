---
name: change-wallpaper
description: 将用户图片补绘并用 Real-ESRGAN 增强为高清 Windows 桌面壁纸，自动识别当前电脑各显示器的真实分辨率、方向与比例，逐屏适配、设置和核验。用于更换壁纸或制作适配显示器的高清背景。
---

# Change Wallpaper

适用于 Windows 10/11 x64。不绑定作者的用户名、硬盘目录、显示器型号、屏幕数量或固定分辨率。只制作图片时不要自动设置桌面；用户已要求更换壁纸时，完成检查后直接设置。

## 依赖与职责

- 读取并使用 `imagegen/SKILL.md`：调用内置 `image_gen` 补充细节、扩展画幅、适配构图。安装技能文件不会开通图片生成服务；工具不可用时说明具体缺失，不擅自切换收费 API。
- 读取并使用 `real-esrgan-skill/SKILL.md`：使用其 `scripts/upscale.ps1` 和 `realesrgan-x4plus` 照片模型，进行实际 4 倍 AI 放大。本包的 Windows 入口不依赖 Python、Git Bash 或 ffmpeg。
- 本技能的 `scripts/wallpaper.ps1` 负责原生屏幕探测、按比例裁边与缩小、逐屏应用、读回及备份恢复。它不替代前两项 AI 处理。

依赖通常位于本技能的同级目录；imagegen 也可能位于用户技能目录下的 `.system/imagegen`。先使用现有依赖，缺少时按包内安装说明安装。

## 工作流程

1. 每次开始先探测实际桌面。不要用受 Windows 缩放影响的 `Screen.AllScreens` 数值当原生像素，不凭“显示器 1/2”或主屏顺序猜身份。

   ```powershell
   & "$skillDir/scripts/wallpaper.ps1" -Mode Inspect
   ```

   输出的 `Id` 是后续写入使用的身份；`Index` 仅是本次探测序号，不保证等于 Windows 设置页编号。每块屏幕默认目标宽、高为探测值的 2 倍，例如 2560×1440 对应 5120×2880。不要修改屏幕自身的分辨率或缩放比例。

2. 用 `view_image` 查看输入，按用户当前要求调用 imagegen。尽量保留原来的主体、配色和光照；竖图改横图优先补画两侧，避免拉伸和大幅裁掉主体。只有用户提出时才改变花量、对象或风格。提示词和检查方法见 [清晰度与补绘](references/quality-and-prompts.md)。

   对相近比例的屏幕可共用一张补绘母图。横竖混用、超宽屏或边缘主体会被裁掉时，应分别生成对应构图，不能靠裁切强行适配。提示词写了“4K”不代表输出文件真的有 4K 像素，必须读取实际宽高。

3. 用依赖技能做实际 AI 放大，输出到新的文件，保留原图。

   ```powershell
   & "$esrganDir/scripts/upscale.ps1" -InputPath $editedImage -OutputPath $aiMaster
   ```

   核验返回的真实宽高为输入的 4 倍。照片默认 `realesrgan-x4plus`，不要用动漫模型处理照片。没有 Vulkan GPU、模型缺失或推理失败时保留已完成文件并说明问题，不能把普通插值冒充 AI 增强。不要无限重试；显存问题只尝试一次较小的 `-TileSize 64`，仍失败就报告。

4. 生成各屏幕专用 PNG。选择一个新的持久输出目录；不要将正在使用的壁纸保存在将被清理的临时目录。

   ```powershell
   & "$skillDir/scripts/wallpaper.ps1" -Mode Prepare -MasterPath $aiMaster -OutputDirectory $out -PixelScale 2
   ```

   脚本按当前每块屏幕的原生比例裁边、缩小并生成 `wallpaper-manifest.json`，包含显示器身份、实际尺寸和 SHA-256。若母图像素不足，脚本会拒绝普通放大；应先提高 AI 母图尺寸再重试。超高分辨率屏幕若当前能力无法达到默认的 2 倍目标，如实说明并与用户明确较低目标，不能暗中降低标准。

   多张母图用 `-SourceMapPath sources.json`，JSON 对象将探测得到的 `Id` 映射到对应 AI 母图绝对路径。可同时给 `-MasterPath` 作为未单独映射的屏幕的来源。

5. 设置前查看每个比例的完整图及细节。检查脸、花瓣、文字、细枝和纹理是否变形、发糊、涂抹或出现锐化白边。原生尺寸下的视觉质量优先于文件大小。`RetainedArea` 表示裁切后保留的面积比例，只是构图检查提示，不能用一个固定阈值代替对主体是否完整的判断。

6. 用户要求更换桌面时，逐屏应用并读回：

   ```powershell
   & "$skillDir/scripts/wallpaper.ps1" -Mode Apply -ManifestPath "$out/wallpaper-manifest.json"
   ```

   脚本再次核对当前屏幕身份、分辨率、方向和文件校验值，再用 Windows `IDesktopWallpaper` 分别设置为 Fill（保持比例填充），将 JPEG 导入质量设为 100，并读取各屏幕的实际图片路径核验。应用前保存旧壁纸路径、显示位置和质量设置；失败时尝试恢复，恢复失败必须明确报告。发生热插拔或旋转导致身份/尺寸变化时，重新探测和准备，不能继续用旧清单。

   恢复之前保存的文件壁纸：

   ```powershell
   & "$skillDir/scripts/wallpaper.ps1" -Mode Restore -ManifestPath $backupJson
   ```

   备份不复制旧图片，也不备份幻灯片播放列表或整个 Windows 主题；旧图片必须仍然存在。

7. 汇报实际完成情况：每屏原生尺寸、已应用图片尺寸、是否读回一致；给出最终文件链接。区分“新增像素”“AI 重建细节”与真实原始细节，不保证恢复未被拍下的信息。保存使用的提示词和处理记录；清理自己的中间文件前确认它们不是当前桌面正在引用的文件。不要将用户图片、屏幕身份或本机路径自动发布到代码仓库。

使用 PowerShell 和 Windows API 完成本流程，不需要 computer-use。
