# string-normalization

## Purpose

定义共享字符串清洗的当前两条公开行为：FoundationKit 为 Swift 字符串提供 trim/empty-to-nil，LegacyCore 为 Objective-C 调用方提供 trim/连续空白折叠。

## Evidence

- Swift `normalizedOrNil` 行为由 `Modules/FoundationKit/Sources/StringNormalization.swift` 的当前实现推导，当前没有直接自动化测试。
- Objective-C `sanitize:` 由 `Apps/DemoPhotoMark/Tests/DemoPhotoMarkTests.swift` 的 `sanitizeCollapsesWhitespace` 与 `sanitizeReturnsEmptyForBlank` 经模块导入覆盖；实现位于 `Modules/LegacyCore/Sources/LGCStringSanitizer.m`。

## Requirements

### Requirement: Swift trim 与 empty-to-nil

系统 SHALL 让 `normalizedOrNil` 去除字符串首尾的空白与换行；清洗后为空时 SHALL 返回 `nil`，否则 SHALL 返回清洗后的字符串。

#### Scenario: Swift 非空字符串去除首尾空白

- **WHEN** Swift 调用方读取 `"  demo  ".normalizedOrNil`
- **THEN** 返回 `"demo"`

#### Scenario: Swift 空白字符串变为 nil

- **WHEN** Swift 调用方读取纯空白或换行字符串的 `normalizedOrNil`
- **THEN** 返回 `nil`

### Requirement: Objective-C trim 与连续空白折叠

系统 SHALL 让 `sanitize:` 去除输入首尾的空白与换行，并将内部连续空白字符折叠为一个空格；纯空白输入 SHALL 返回空字符串。

#### Scenario: Objective-C 连续空白被折叠

- **WHEN** 调用方清洗 `"  hello   world "`
- **THEN** 返回 `"hello world"`

#### Scenario: Objective-C 纯空白返回空字符串

- **WHEN** 调用方清洗纯空白字符串
- **THEN** 返回空字符串
