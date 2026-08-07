# design-components

## Purpose

定义 DesignKit 当前公开主题 token 与 TagChip 的文本回退、排版和胶囊背景表现，为现有调用方提供可读的行为基线。

## Evidence

- 下列行为由 `Modules/DesignKit/Sources/StudioTheme.swift` 与 `Modules/DesignKit/Sources/TagChip.swift` 的当前实现推导。
- 当前没有自动化测试覆盖本 capability；本基线不把实现推导描述为已测试保证。

## Requirements

### Requirement: 暴露当前主题 token

系统 SHALL 公开值为 `12` 的圆角半径 token，并公开橙色作为 accent token。

#### Scenario: 调用方读取主题 token

- **WHEN** 调用方读取 `StudioTheme.cornerRadius` 与 `StudioTheme.accent`
- **THEN** 分别得到 `12` 与橙色

### Requirement: TagChip 规范化文本并提供空值回退

系统 SHALL 在初始化 TagChip 时去除原始文本首尾空白；清洗后为空时 SHALL 展示长破折号 `—`，否则 SHALL 展示清洗后的文本。

#### Scenario: 有效标签去除首尾空白

- **WHEN** 调用方使用 `"  demo  "` 创建 TagChip
- **THEN** 标签文本显示为 `"demo"`

#### Scenario: 空白标签使用回退文本

- **WHEN** 调用方使用纯空白文本创建 TagChip
- **THEN** 标签文本显示为 `—`

### Requirement: TagChip 使用当前胶囊样式

系统 SHALL 以 caption 字体展示标签文本，应用水平 `10`、垂直 `4` 的内边距，并使用透明度 `0.15` 的 accent 色胶囊背景。

#### Scenario: 渲染标签外观

- **WHEN** TagChip 渲染有效或回退文本
- **THEN** 文本使用 caption 字体与规定内边距，背景为规定透明度的 accent 色胶囊
