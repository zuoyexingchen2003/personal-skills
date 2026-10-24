# Personal Skills

可安装、可分享的个人 Codex 技能。首个组合是 **change-wallpaper**：把一张图片补充细节、适配构图，再做实际 AI 超分辨率处理，为当前电脑的每块显示器分别生成和设置高清壁纸。

**当前版本 V1.1：Windows 10/11 x64，以及 macOS 12+ 的 Intel 和 Apple Silicon。** 自动识别当前电脑屏幕，支持不同方向、比例与分辨率的组合。默认壁纸宽、高为每屏当前像素尺寸的 2 倍，像素总数为 4 倍。Mac 区分 Retina 界面点数与实际渲染像素；“更多空间”模式下渲染像素可能高于物理面板规格，不混称两者。像素标准和视觉检查同时执行。

[下载 V1.1 安装包](https://github.com/zuoyexingchen2003/personal-skills/releases/tag/V1.1) · [Windows 说明](docs/USER_GUIDE.md) · [Mac 说明](docs/MACOS.md) · [验证记录](docs/VALIDATION.md) · [版本记录](docs/VERSIONS.md)

## 包含什么

| 内容 | 作用 | 来源 |
|---|---|---|
| `skills/change-wallpaper` | 探测屏幕、组织处理流程、按屏幕比例生成、逐屏设置和核验 | 本仓库 |
| `skills/imagegen` | 调用内置图片工具补绘细节、扩展画幅、修改用户指定的内容 | OpenAI imagegen skill，保留 Apache-2.0 许可证 |
| `skills/real-esrgan-skill` | 实际 4 倍 AI 放大 | pangpang778 原技能，加本仓库 Windows / Mac 入口 |
| 完整安装包中的引擎和模型 | 对应平台的 GPU 高清处理 | Real-ESRGAN 官方 Windows 或 macOS universal 发行版 |
| Mac 原生屏幕工具 | Retina 像素探测、图像准备、逐屏设置与恢复 | 本仓库 Swift 源码编译的 Intel / Apple Silicon universal helper |

源代码仓库不提交大型引擎文件；**Release 的完整 ZIP 已包含引擎和模型**。只克隆源代码也能使用，首次运行会从官方 GitHub 下载引擎并校验固定 SHA-256。不会从第三方镜像下载执行程序。

## 使用前需要什么

- Windows：Windows 10/11 x64、PowerShell 5.1/7、驱动正常且支持 Vulkan 的显卡。
- Mac：macOS 12+ 的 Intel 或 Apple Silicon，以及可用 Metal/MoltenVK GPU。完整 Mac 包带预编译工具，不需要 Xcode；只用源码时才需要 Apple Command Line Tools。
- 两平台图片流程都无需 Python、PyTorch、CUDA 或 ffmpeg；Mac 使用系统 Bash，Windows 不需要 Git Bash。
- 能使用内置 `image_gen` 图片工具的 Codex 环境。**技能文件是操作说明，不包含图片生成服务，也不会开通账号权限。** 已有内置工具时不需要提供 OpenAI API key；工具缺失时不能靠安装此包获得该工具。

本包不会更改显示器分辨率、Windows 缩放或全局 PowerShell 执行策略。GPU 推理是否可用取决于具体显卡和驱动；失败会报告，不会静默改用普通缩放。

## 安装

1. 从 V1.1 Release 下载对应的 `personal-skills-change-wallpaper-V1.1-windows.zip` 或 `personal-skills-change-wallpaper-V1.1-macos.zip`，解压。原 Windows 包保留为 V1.0。
2. 在解压后的 `personal-skills` 文件夹打开 PowerShell，运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
   ```

   Mac 在终端进入解压后的 `personal-skills` 目录，运行：

   ```bash
   bash scripts/install.sh
   ```

   `Bypass` 仅对本次进程生效，不修改系统策略。安装器使用 `CODEX_HOME/skills`；未设置 `CODEX_HOME` 时使用当前用户的 `.codex/skills`。已有内置 imagegen 会直接复用。已有同名个人技能默认保留，不会直接覆盖。

3. 在下一轮 Codex 对话中调用：

   ```text
   $change-wallpaper 把这张图做成高清壁纸，适配当前电脑的所有显示器并设置为桌面。
   ```

   然后附上图片，或提供本机图片路径。仅希望制作文件时，明确说“只生成，不设置”。

更新已有同名技能：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Update
```

安装器先把旧技能复制到技能目录旁的 `skill-backups`，再替换。已有内置 imagegen 始终保留。也可以用 `-SkillsRoot 'D:\CodexSkills'` 安装到指定目录，但 Codex 仍需配置为发现该目录。

Mac 更新用 `bash scripts/install.sh --update`，先将旧技能移到 `skill-backups`；指定目录使用 `--skills-root /path/to/skills`。完整 Mac 包先校验逐文件 SHA-256。系统可能要求批准单个未公证程序；本流程不移除 quarantine 或关闭 Gatekeeper，见 [Mac 说明](docs/MACOS.md)。

## 实际怎么处理

1. 读取当前活动显示器的唯一身份和真实像素尺寸，避开 DPI 缩放造成的尺寸误判。
2. 通过 imagegen 保留原图主体并补绘细节、扩展画幅。横竖混用或超宽屏需要时分别做构图。
3. 通过 Real-ESRGAN 的照片模型进行真实 4 倍放大，核对输出宽高。
4. 从 AI 母图为每块屏幕分别裁边和高质量缩小，保存无损 PNG；母图不足时拒绝普通插值放大。
5. 检查各比例完整画面、100% 局部和原生屏幕大小下的细节。
6. 备份旧壁纸设置，逐屏应用并读取系统实际路径核验。屏幕配置变化时重新探测，不拿旧身份继续写。

例如下面的双屏会得到不同文件；这些数值是实测示例，不是程序中固定的配置：

| 原生屏幕 | 画面比例 | 默认壁纸 |
|---|---|---|
| 1920×1200 | 16:10 | 3840×2400 |
| 2560×1440 | 16:9 | 5120×2880 |
| 1080×1920 | 竖屏 9:16 | 2160×3840，需检查独立构图 |

AI 会推断新增纹理。新增花朵、补画区域和重建纹理属于生成内容；不能保证恢复原图未记录的真实信息。最终是否自然、清楚，必须看图，不能只看分辨率数字。

## 安全性与恢复

设置前检查所有图片都存在、像素符合目标、SHA-256 未改变，且屏幕身份和尺寸仍然一致。只有用户要求更换桌面才应用。修改前会创建 `wallpaper-backup-*.json`；应用失败时尝试恢复旧壁纸，恢复失败会明确抛错。

恢复见 [Windows 说明](docs/USER_GUIDE.md#7-恢复旧壁纸)和 [Mac 说明](docs/MACOS.md)。备份不复制旧图片，不保存完整动态主题或所有 macOS Space 的状态。Mac 使用 NSWorkspace，允许有限刷新时间后读回核验；不批量控制其他 Space 或锁屏。请保留桌面正在引用的图片。

本仓库和发布包不包含作者的照片、账号令牌、私有配置、显示器设备身份或个人绝对路径。安装包内 `SHA256SUMS.txt` 可用于完整性核验。

## 开发与重新打包

```powershell
.\scripts\build-package.ps1 -Platform windows -OutputPath .\dist\personal-skills-change-wallpaper-V1.1-windows.zip
.\scripts\build-package.ps1 -Platform macos -MacToolPath .\ci-artifact\wallpaper-macos -OutputPath .\dist\personal-skills-change-wallpaper-V1.1-macos.zip
```

脚本校验对应平台官方引擎，将三个技能、文档、许可证、运行时及校验清单打包。已有运行时可用 `-RuntimeDirectory` 指定。Mac 工具来自本仓库双架构 CI，旁边的 `source.sha256` 必须与当前 Swift 源码匹配。ZIP 不包含 `.git`、缓存、用户图片或凭据；校验清单采用 UTF-8 无 BOM、LF 换行，兼容 Mac `shasum`。

[Intel 与 Apple Silicon CI](https://github.com/zuoyexingchen2003/personal-skills/actions/runs/40083427744) 均实际完成屏幕探测、设置、恢复和 64×64→256×256 的 GPU 推理。它们是托管 macOS 测试机，实体 Retina 多屏和大幅照片的 Mac 全流程视觉效果仍须在目标电脑核验。

## English quick start

V1.1 supports Windows 10/11 x64 and macOS 12+ on Intel/Apple Silicon. Download your platform's ZIP, extract it, then run `scripts/install.ps1` on Windows or `bash scripts/install.sh` on Mac. Use `$change-wallpaper` in the next Codex turn. Each screen gets its own aspect ratio and pixel target; Retina UI points are not pixels. Both packages include the three skills and platform engine/models; Mac also includes a prebuilt universal helper. A working GPU and Codex's built-in image generation tool are required; installing skills does not enable that service. The original Windows release remains available as V1.0.

## 许可证

本仓库新写的流程、PowerShell 脚本和文档采用 MIT。随附第三方文件继续遵守各自许可证，参见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
