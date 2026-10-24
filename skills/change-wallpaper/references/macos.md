# macOS V1.1

面向 macOS 12+ 的 Intel 和 Apple Silicon，使用 AppKit/CoreGraphics、ImageIO 和 CryptoKit。完整 macOS ZIP 包含预编译的 universal 原生工具及官方 universal Real-ESRGAN 引擎，不要求安装 Python、ffmpeg、Homebrew 或 Xcode。只安装源码时需要 Apple Command Line Tools 来编译 Swift；检测缺少时说明，不自动安装。

## 屏幕和 Retina

```bash
bash "$skillDir/scripts/wallpaper-macos.sh" inspect
```

`Id` 是 CoreGraphics 显示器 UUID，应用时按 UUID 匹配，不靠主屏或屏幕顺序。`LogicalWidth/LogicalHeight` 是界面点数；`BackingScaleFactor` 是 Retina 倍率。`Width/Height` 使用当前 display mode 的像素与 backing 像素，并按实际横竖方向处理，不能把点数当像素，也不能固定假定所有 Mac 都是 2× Retina。

在 macOS 的某些“更多空间”缩放设置中，当前渲染像素可能高于物理面板像素；输出明确标为 `SizeBasis=current display-mode/backing pixels`，不声称已经读出了面板原生规格。默认仍以这些像素尺寸的宽、高各 2 倍制作壁纸，确保覆盖当前渲染需求。超高目标达不到时按共同清晰度要求说明，不暗中降低。

## 补绘和实际 AI 放大

按主 SKILL 的要求先查看输入，再通过内置 imagegen 补充细节并适配每种比例。横竖混用或重要主体在边缘时，分别补绘构图。每张补绘结果再运行：

```bash
bash "$esrganDir/scripts/upscale-macos.sh" "$editedImage" "$aiMaster"
```

该入口运行官方 Real-ESRGAN universal 引擎，实际执行 `realesrgan-x4plus` 4 倍 GPU 放大，并通过系统 `sips` 验证宽高。默认分块 128；显存问题可只重试一次分块 64，第三个参数即分块尺寸。Metal/MoltenVK GPU 不可用时明确失败，不用普通缩放冒充。

完整包带运行时；源码安装的首次运行只从官方发布下载，并验证固定 SHA-256。Mac 可能要求用户批准单个未公证的程序：核对发布包校验值后按系统提示处理，不能自行移除 quarantine、关闭 Gatekeeper 或全局修改系统安全设置。上游 README 中较早的全局关闭 Gatekeeper 建议不属于本技能流程。

## 分屏生成、应用与恢复

```bash
bash "$skillDir/scripts/wallpaper-macos.sh" prepare --master "$aiMaster" --output "$out" --pixel-scale 2
bash "$skillDir/scripts/wallpaper-macos.sh" apply --manifest "$out/wallpaper-manifest.json"
bash "$skillDir/scripts/wallpaper-macos.sh" restore --manifest "$backupJson"
```

多母图通过 `--sources sources.json` 将显示器 UUID 映射到对应 AI 母图路径，可同时用 `--master` 提供默认母图。`prepare` 只裁边和缩小，像素不足就拒绝；同样生成 PNG、SHA-256 和清单。设置前完成完整图、100% 局部及屏幕原生大小下的视觉检查。

`apply` 必须有当前用户更换桌面的授权；先核对 UUID、像素、方向、文件尺寸和校验值，备份每屏旧图片 URL 与缩放/裁边/填充色选项，再在主线程调用 `NSWorkspace.setDesktopImageURL`。设置后的路径读回允许有限的系统刷新时间，不能因为方法返回就声称已设置。失败时尝试恢复，并明确报告恢复失败。

只对当前登录桌面会话的各屏幕操作，不保证覆盖其他 Space、Stage Manager 工作空间、锁屏、动态/视频壁纸，也不要求开启辅助功能控制权限。备份不复制旧图片，不保存整套系统壁纸主题；旧静态图片 URL 无法使用时不能声称已恢复。

## 验证边界

原生工具的 `self-test --output DIR` 只生成合成图并检查横竖裁切和像素拒绝，不能称为真实显示器调用。`desktop-test --output DIR` 会实际临时更换并恢复当前桌面，仅在已获授权的隔离测试会话使用。发布记录应分别列出编译、安装、原生探测/应用/恢复、GPU 推理与实体 Retina 多屏视觉验证，未做的项目不得归为已验证。

依据：[Apple 设置桌面图像 API](https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl(_:for:options:))、[Apple display mode 像素宽度](https://developer.apple.com/documentation/coregraphics/cgdisplaymode/pixelwidth)。
