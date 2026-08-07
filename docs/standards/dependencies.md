# 依赖工程标准

本文件解释 Apple target 如何消费第三方库以及升级时要关注的工程风险。依赖声明位置的仓库 Gate 只在 `GOVERNANCE.md` 的 `GATE-DEPENDENCY-SOURCE` 定义。

## 单一版本图

整个 workspace 从 `Tuist/Package.swift` 解析一套第三方依赖版本，App 和共享模块在 manifest 中使用 `.external(name:)` 消费同一解析结果。`Tuist/Package.resolved` 保存可复现解析结果。

单一版本图避免同一 framework 在不同 App 中出现不兼容构建。它也意味着共享公开 API 的演进应优先增加新接口、逐步废弃旧接口；破坏性升级需要同时验证所有使用方。

## 引入或升级库

1. 阅读上游 release notes，确认最低系统、Swift/Xcode、隐私清单和二进制架构要求。
2. 修改 `Tuist/Package.swift`，运行 `mise exec -- tuist install` 更新解析结果。
3. 重新 generate，构建全部 App，并运行影响面测试；命令见 `RUNBOOK.md`。
4. 检查公开 API、App 启动、资源 bundle、隐私清单和 Objective-C linker flag 是否受影响。

一次只升级一个高风险依赖，能让失败来源和回滚点保持清楚。

## 只有 CocoaPods 分发的 SDK

优先顺序：

1. 用薄模块隔离 SDK API，让业务代码不直接 import 厂商类型。
2. 能稳定重现时，将 SDK 制作为 XCFramework，由 Tuist 作为二进制依赖接入。
3. 如果授权、架构、隐私或维护状态不合适，替换 SDK 或自行实现所需能力。

不要让 CocoaPods workspace 成为这个 Tuist workspace 的第二套工程图。

## 工具链依赖

Tuist、Node 和 OpenSpec 由 `mise.toml` 锁定；Xcode marketing version 与 build identity 分别由 `.xcode-version`、`.xcode-build-version` 锁定。升级时同时验证 manifest 解析、schema、生成、构建与测试，具体入口见 `RUNBOOK.md`。
