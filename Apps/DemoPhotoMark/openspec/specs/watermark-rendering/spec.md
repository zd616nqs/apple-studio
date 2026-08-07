# watermark-rendering

## Purpose

定义 DemoPhotoMark 当前文字水印渲染边界：输入标注文本先按共享清洗规则规范化，空白标注不产生图片，有效标注按调用方请求的尺寸生成图片。

## Evidence

- `Apps/DemoPhotoMark/Tests/DemoPhotoMarkTests.swift` 的 `normalizedCaptionUsesSharedSanitizer`、`imageIsNilForBlankText` 与 `imageRendersAtRequestedSize` 覆盖下列全部要求。
- `Apps/DemoPhotoMark/Sources/PMWatermarkRenderer.m` 是当前实现入口。

## Requirements

### Requirement: 规范化水印标注

系统 SHALL 在渲染前去除标注文本首尾的空白与换行，并将内部连续空白折叠为一个空格。

#### Scenario: 清洗首尾与连续空白

- **WHEN** 调用方提交 `"  Demo   PhotoMark "`
- **THEN** 规范化结果为 `"Demo PhotoMark"`

### Requirement: 拒绝空白水印

系统 SHALL 在规范化结果为空字符串时拒绝生成水印图片，并返回无图片结果。

#### Scenario: 纯空白标注不生成图片

- **WHEN** 调用方请求使用纯空白文本生成水印
- **THEN** 返回 `nil`，不产生图片

### Requirement: 保持请求的输出尺寸

系统 SHALL 为非空标注生成图片，并使图片逻辑尺寸等于调用方请求的尺寸。

#### Scenario: 按指定尺寸生成水印

- **WHEN** 调用方使用有效标注请求 `120 × 40` 的图片
- **THEN** 返回非空图片，且图片尺寸为 `120 × 40`
