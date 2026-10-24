# 清晰度与补绘

## 目标和分辨率

默认目标是每块屏幕的宽、高各为原生分辨率的 2 倍，也就是 4 倍像素总数。先为图像补充构图和可辨认的细节，再做 Real-ESRGAN 超分辨率处理（用神经网络重建放大后的纹理），最后缩小到各屏幕目标。不能只修改文件的宽高或 DPI 数字后宣称图像更清晰。

默认 4 倍 AI 放大并非“反复做得越多越好”。重复超分辨率可能使花瓣、毛发和砖纹变得塑料化或产生重复假细节。母图不足时，优先让 imagegen 输出更合适的构图和尺寸；如必须再次放大，实际检查效果并记录处理次数。

## 补绘提示词示例

按实际图片与用户要求替换方括号，不照搬题材或固定花量：

```text
Input image is the edit target. Preserve the original subject, identity,
proportions, colors, materials, camera perspective and light direction.
Enhance natural fine detail on [subject-specific important features].
Adapt the composition to [target aspect ratio] for a desktop wallpaper.
Outpaint [necessary edges] as a seamless continuation of the original scene.
Keep all important subject parts within the usable region shared by
[screen aspect ratios], or create a dedicated composition for each ratio.
Make only this user-requested creative change: [requested change, if any].
Keep a photographic appearance; no waxy smoothing, repeated fake textures,
sharpening halos, stretched subjects, added text, logos or watermarks.
Request high resolution, then verify the actual file dimensions separately.
```

宽屏与竖屏混用时，不应把一张横图裁成极窄的中间条。先看主体位置；必要时分别补绘 16:9、16:10、9:16、21:9 等实际所需构图，再对各张图做 AI 放大。源图映射文件的键是 `Inspect` 输出的 `Id`，值是完成 AI 放大的母图路径。

## 视觉核验

1. 完整图：检查主体是否完整、比例自然、扩展边缘是否连续，确认各屏幕画幅都有合理构图。
2. 100% 图像局部：检查花瓣、毛发、皮肤、文字、砖石或枝条边缘，识别白边、假纹理、重影和涂抹。
3. 原生屏幕大小：高分辨率图片缩小到该屏幕原生尺寸后，再检查代表性局部。2 倍大图的像素数不能证明真实显示效果。
4. 执行核验：文件可正常打开，真实尺寸符合目标；应用后逐屏路径和 Fill 位置读回一致。

可以用 `System.Drawing.Bitmap.Clone()` 截取图片局部进行 QA，再用 `view_image` 查看；这是图像文件检查，不需要截图或控制桌面应用。对花瓣/树枝等微细目标，局部应同时包含主体边缘与相邻背景，便于看出锐化白边。不要为了让比较图更漂亮给两边施加不同的后处理。

保留检查结果和实际不足。AI 处理会推断纹理，新增花朵、纹理与扩展画面属于生成内容，不等同于恢复原照片中不可见的真实信息。
