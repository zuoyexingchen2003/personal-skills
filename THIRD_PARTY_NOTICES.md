# Third-party notices

The original workflow, Windows adapter, installer, packaging scripts and repository documentation are MIT licensed. Third-party files retain their original licenses.

| Component | Upstream | License and included notice |
|---|---|---|
| imagegen skill | OpenAI bundled Codex imagegen skill; [OpenAI skill documentation](https://developers.openai.com/plugins/build/skills) | Apache-2.0, `skills/imagegen/LICENSE.txt`. Copied without modifying its tool/API authorization rules. |
| real-esrgan-skill | [pangpang778/real-esrgan-skill](https://github.com/pangpang778/real-esrgan-skill) | MIT, `skills/real-esrgan-skill/LICENSE`. Added a Windows PowerShell image entry point and its documentation; original shell path retained. |
| Real-ESRGAN model/project | [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) | BSD-3-Clause; upstream license included in `skills/real-esrgan-skill/licenses/Real-ESRGAN-LICENSE.txt`. |
| Real-ESRGAN ncnn/Vulkan engine | [xinntao/Real-ESRGAN-ncnn-vulkan](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan) | Upstream license in `skills/real-esrgan-skill/licenses/Real-ESRGAN-ncnn-vulkan-LICENSE.txt`; official portable release files and its README are retained in the complete ZIP. |

The complete ZIP redistributes the official Windows portable runtime, including its DLLs and model files. Those bundled upstream components retain their applicable licenses; the MIT license of this repository does not relicense them. The official engine README identifies its ncnn and realsr-ncnn-vulkan dependencies.

Runtime source: `https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip`.

Pinned official archive SHA-256: `ABC02804E17982A3BE33675E4D471E91EA374E65B70167ABC09E31ACB412802D`.

No API credentials, account access, or rights to a particular user's input images are included in this distribution. Installing the imagegen instructions does not enable an unavailable hosted image generation tool.
