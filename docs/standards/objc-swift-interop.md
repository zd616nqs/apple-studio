# Swift 与 Objective-C 混编标准

Objective-C 在本仓库是一等实现语言。本文件只描述代码、编译和链接边界；工作流要求见 `GOVERNANCE.md`。

## 两条互操作路径

| 场景 | 推荐路径 | 原因 |
| --- | --- | --- |
| Swift/Objective-C 调用共享 Objective-C framework | Swift `import LegacyCore`；Objective-C `@import LegacyCore` | framework 自带 module 边界，不依赖调用方桥接头 |
| Swift 调用同一 App target 内的 Objective-C | `Sources/BridgingHeader.h` | 桥接头只服务一个编译 target |
| Swift Testing 调同一 App 的 Objective-C | `Tests/BridgingHeader.h` | 测试 target 有独立编译边界 |

共享模块的公开头不放进 App 桥接头。Objective-C framework 使用与模块同名的 umbrella header 暴露 public header。

## Nullability 与 Swift 导入形态

公开 Objective-C 头使用 `NS_ASSUME_NONNULL_BEGIN/END` 包围默认非空区域，真实可空值显式写 `nullable`。Block、delegate、NSError、collection element 和 completion result 都要检查导入 Swift 后的可选性。

在改公开头后，从 Swift 调用点验证实际导入签名；仅看 Objective-C 声明容易漏掉命名和可选性变化。

## 语言模式与并发边界

纯 Swift target 使用 Swift 6 模式。当前混编 App/Objective-C 目标保持 Swift 5 模式，以隔离遗留导入与严格并发迁移成本。跨语言回调进入 Swift concurrency 时，把线程、actor、取消和生命周期约束写在封装层，不把裸 Objective-C callback 扩散到 UI。

混编 target 升级 Swift 语言模式属于独立工程迁移，需要先清点 Sendable、主线程 UI、delegate 生命周期和第三方 header 的导入结果。

## `-ObjC` 与 category 链接

Objective-C category 可能因为没有直接符号引用而被静态链接器裁掉，表现为编译成功但运行时 `unrecognized selector`。Studio 的混编配置提供 `-ObjC` 基线，测试宿主启动能覆盖这类失败。

当前存在一个已登记的后续修复：自定义 build settings 的合并顺序可能覆盖工厂提供的 linker flag。在修复合并前，修改混编 target settings 后应检查最终 `OTHER_LDFLAGS` 并运行 App 测试；不要把“工厂曾设置”当成最终生效证据。
