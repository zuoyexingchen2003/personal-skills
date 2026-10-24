# 版本记录

| 版本 | 平台 | 发布 |
|---|---|---|
| V1.0 | Windows 最初发行版 | [原发行版](https://github.com/zuoyexingchen2003/personal-skills/releases/tag/change-wallpaper-v1.0.0)，保留原 tag 和下载地址，显示名称改为 V1.0 |
| V1.1 | Windows + macOS Intel / Apple Silicon | [V1.1](https://github.com/zuoyexingchen2003/personal-skills/releases/tag/V1.1)，分别提供 Windows、Mac 完整包 |

V1.1 新增 Mac 原生探测、Retina 点数与像素区分、逐屏设置和读回、备份恢复、Mac 安装器、官方 Mac 引擎入口与 universal 原生工具。三个技能与各平台运行时均包含在对应安装包中。

Mac 路径通过 [Intel / arm64 CI](https://github.com/zuoyexingchen2003/personal-skills/actions/runs/40083427744) 的编译、安装、图像处理、原生桌面 API 和真实 GPU 小图推理测试。实体 Retina 多屏与完整照片视觉效果仍须在目标电脑检查。

V1.0 的提交、tag、资产和校验值均保留。V1.1 不改写 Git 历史，不覆盖旧安装包。
