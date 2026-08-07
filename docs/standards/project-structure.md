# 工程结构标准

Tuist manifest 是工程结构的可读来源。`Workspace.swift` 组合项目，App/Modules 的 `Project.swift` 声明 target，`Tuist/ProjectDescriptionHelpers/Studio.swift` 提供共享工厂。生成的 Xcode project/workspace 只是可重建输出。

## App 目录

```text
Apps/<Name>/
├── CONTEXT.md
├── Project.swift
├── Sources/
├── Resources/
├── Tests/
└── openspec/
```

`Studio.app(...)` 读取 `Sources/**`、`Resources/**` 和 `Tests/**`。混编 App 通过 `hasObjC: true` 启用桥接头约定；具体路径见 `objc-swift-interop.md`。App 领域术语放 `CONTEXT.md`，target/依赖事实留在 `Project.swift`。

新增 App 时：

1. 从匹配语言模式的 Demo App 复制目录骨架，再改名称、bundle ID、依赖和资源。
2. 在 `Workspace.swift` 注册 App 路径。
3. 初始化产品 OpenSpec store，并按 `GOVERNANCE.md` 建立两套 schema 的相对入口；config 只写该 App 上下文与 archive 规则 ID 指针。
4. 运行 OpenSpec schema/content validation、Tuist generate、全量 build 和新 App 测试。

当前 factory 只证明 `GOVERNANCE.md` 中的 verified 范围；committed 平台/产品目标在拥有 factory、示例、构建和测试前不作为模板使用。

## Modules 目录

`Modules/Project.swift` 集中声明多个 framework。Swift 与 Objective-C 使用独立 target，通过 module import 组合，避免共享层桥接头。

把能力提取到 Modules 前，先确认至少有第二个真实使用方。新增模块时同时考虑：

- public API 与访问控制；
- 资源 bundle 和依赖方向；
- Objective-C umbrella header；
- Swift 语言模式和并发边界；
- 所有依赖 App 的构建与测试影响。

## 工厂扩展

新增平台或产品 target 使用明确 factory，保留平台差异，不提供吞掉所有参数的通用 `extension()`。一个支持状态升级到 verified 的证据集合是：factory、仓库内示例、可重复构建和测试。
