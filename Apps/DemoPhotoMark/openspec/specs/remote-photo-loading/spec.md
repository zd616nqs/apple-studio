# remote-photo-loading

## Purpose

定义 DemoPhotoMark 当前远程图片视图的可观察加载反馈与展示方式：请求期间显示进度反馈，完成回调清理反馈，图片在视图边界内以 aspect-fill 呈现。

## Evidence

- 下列行为由 `Apps/DemoPhotoMark/Sources/PMRemotePhotoView.m` 的当前实现推导。
- 当前没有自动化测试覆盖本 capability；本基线不把实现推导描述为已测试保证。

## Requirements

### Requirement: 请求期间显示进度反馈

系统 SHALL 在开始远程图片请求时，将可见的进度 HUD 添加到远程图片视图。

#### Scenario: 开始加载远程图片

- **WHEN** 调用方要求远程图片视图加载一个 URL
- **THEN** 图片请求启动，并在该视图上显示进度 HUD

### Requirement: 完成回调清理进度反馈

系统 SHALL 在图片加载 completion 被调用时隐藏本次请求创建的进度 HUD，无论 completion 携带图片还是错误。

#### Scenario: 图片请求结束

- **WHEN** 远程图片请求的 completion 被调用
- **THEN** 本次请求对应的进度 HUD 以动画方式隐藏

### Requirement: 图片按 aspect-fill 展示

系统 SHALL 让内部图片视图填满远程图片视图边界，使用 aspect-fill 内容模式，并裁剪超出边界的内容。

#### Scenario: 容器完成布局

- **WHEN** 远程图片视图获得布局边界
- **THEN** 内部图片视图占据完整边界，并以裁剪的 aspect-fill 方式展示图片
