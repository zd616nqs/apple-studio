---
name: apple-api-lookup
description: 查询/解释 Apple 开发 API 时的信息源优先级。任何涉及 UIKit/SwiftUI/Foundation/AppKit 等 Apple 框架的 API 用法、签名、可用性(availability)、废弃状态、新特性解释的问题都适用——包括"这个 API 怎么用"、"iOS 多少支持"、"有没有替代 API"、WWDC 新 API 咨询。
---

# Apple API 查询优先级

解释或调用 Apple API 前,按此顺序取证。**核心原则:不臆造 API——三层都查不到就明说查不到,绝不编造签名或可用性**。

## 优先级阶梯

### 1️⃣ Xcode MCP(首选:官方,且与本机 SDK 版本一致)

会话里有 Xcode 提供的 MCP 工具(工具名含 `xcode`)时,API 文档/符号签名/可用性一律先查它:

- 它读的是本机 Xcode 内置文档与 SDK,版本与实际编译环境**完全一致**(本仓 .xcode-version 钉的那个)
- 平台/版本可用性、废弃标注、Swift 与 ObjC 双签名以它为准
- 工具被延迟加载时先用 ToolSearch 按 "xcode" 加载;会话里找不到任何 xcode MCP 工具→提示用户在
  Xcode 设置(Intelligence)里启用 MCP 后重连,然后降级到 2️⃣

### 2️⃣ Agent 自带 WebSearch(次选:官方在线文档)

- 优先限定官方域:developer.apple.com 的文档页与 WWDC session
- 适用:1️⃣ 不可用、或要查比本机 SDK 更新的 beta API、跨版本历史演变

### 3️⃣ 第三方搜索增强(最后:社区经验)

- agent-reach 等工具查社区实践:已知 bug、workaround、真机行为与文档不符的坑
- 社区结论必须标注来源,与官方文档冲突时以官方为准并指出冲突

## 落笔要求

- 给出的每个 API 标注可用性(如 `iOS 17.0+`),与本仓部署目标(iOS 18 / macOS 15)对照,
  低于部署目标的 availability 检查提醒删除,高于的提醒加 `if #available`
- beta-only API 明确标注"beta,正式版可能变",且默认不进主分支代码(蓝图 beta 通道纪律)
- 查询过程不写进代码注释;结论(为什么选这个 API)有必要时写进 change 的 design/proposal
