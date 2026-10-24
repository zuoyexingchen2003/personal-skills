# real-esrgan-skill

给 AI 装上"超分辨率"手艺：一条命令把图片/视频放大 2×~4×，基于 [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)（ncnn-vulkan 版）。

装好之后你只需要对 AI 说：

> 帮我把 demo.mp4 超分到 4 倍
>
> 把这张糊图放大 4 倍

AI 会自动完成：引擎下载 → 抽帧 → 逐帧超分 → 重编码回视频（保留音轨）。图片则一步超分。

## 效果参考

480p 的 AI 生成视频，4× 超分后输出 1920×1088 级别成片（RTX 4060 笔记本约 2.5 秒/帧）。

## 一键安装

### 方式一：把下面这段话粘给任何 AI（推荐）

```text
帮我安装 real-esrgan-skill 技能包，步骤：
1. git clone https://github.com/pangpang778/real-esrgan-skill.git 到临时目录
2. 把仓库里的 SKILL.md 和 scripts/ 拷贝到 ~/.claude/skills/real-esrgan-skill/
   （Windows 即 %USERPROFILE%\.claude\skills\real-esrgan-skill\）
3. 跑一遍仓库里的安装脚本（bash install.sh 或 PowerShell install.ps1 也可以）
4. 装完告诉我怎么用
```

### 方式二：手动两行

```bash
git clone https://github.com/pangpang778/real-esrgan-skill.git
bash real-esrgan-skill/install.sh    # Windows PowerShell: install.ps1
```

装完重启 Claude Code 会话即可。首次使用时 AI 会自动下载对应平台的推理引擎（约 45-50MB，国内网络失败会自动走 gh-proxy 镜像）。

## 参数

| 参数 | 默认 | 说明 |
|------|------|------|
| 输入文件 | 必填 | 图片（png/jpg/webp）或视频（mp4 等） |
| `-s` | 4 | 放大倍数 2/3/4 |
| `-n` | realesrgan-x4plus | 模型：`realesrgan-x4plus`（实拍/通用）、`realesrgan-x4plus-anime`（动漫）、`realesr-general-x4v3`（小而快） |
| `-o` | `<输入名>_x<倍数>.<ext>` | 输出路径 |

## 环境要求

- **显卡**：支持 Vulkan 的 GPU（NVIDIA / AMD / Intel 均可）——硬性要求
- **ffmpeg**：视频模式需要；缺失时 AI 会给出安装命令并征得你同意后才装
- 引擎二进制不进仓库，首次运行自动下载缓存到 `~/.real-esrgan-skill/bin/`

## 平台支持

| 平台 | 状态 |
|------|------|
| Windows | ✅ 实测 |
| macOS | ⚠️ 未实测（官方有二进制） |
| Linux | ⚠️ 未实测（官方有二进制） |

## English Quick Start

```text
Paste this to your AI assistant:

Install the real-esrgan-skill package:
1. git clone https://github.com/pangpang778/real-esrgan-skill.git
2. Copy SKILL.md and scripts/ into ~/.claude/skills/real-esrgan-skill/
3. Run bash install.sh, then tell me how to use it
```

Then just say: *"upscale my video 4x"* or *"enhance this photo"*.

## 常见问题

- **国内下载引擎慢/失败？** 脚本已内置 gh-proxy 镜像自动重试；也可以手动下载 zip 解压到 `~/.real-esrgan-skill/bin/`
- **没有 N 卡行不行？** 行，Vulkan 都行（A 卡/Intel 核显）；没有 GPU 则无法使用
- **显存不够（OOM）？** 直接调用 exe 加 `-t 128`（分块计算）
- **视频里的文字超分后是乱的？** 正常——模型重绘字形但不认识字，AI 生成视频里的横幅/字幕文字超分后可能变形
- **能凭空上到真 4K 吗？** 放大倍数是整数倍，480p 源 4× 后是 1920p；模型重建细节但不发明不存在的像素

## 致谢 & 协议

- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)（BSD-3-Clause）— 超分模型与 ncnn-vulkan 引擎
- [ncnn](https://github.com/Tencent/ncnn) — 腾讯开源推理框架

本仓库的脚本与文档采用 [MIT](LICENSE) 协议；上游模型与引擎各自的协议归属原作者。
