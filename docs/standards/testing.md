# 测试工程标准

测试验证公开行为与失败条件，不固定私有实现。运行命令集中在 `RUNBOOK.md`，何时必须运行由 `GATE-REQUIRED-VERIFICATION` 决定。

## 测试边界

- 把业务逻辑放在可脱离 UI 构造的类型中；DemoNotes 的 `NotesStore` 是当前示例。
- Swift target 使用 Swift Testing。测试命名表达输入、事件和可观察结果。
- Objective-C framework 通过 module import 测试；同一 App target 的 Objective-C 使用测试桥接头。
- UI 测试覆盖真正依赖系统交互的关键路径，避免用 UI 测试重复验证纯逻辑。
- 网络与时间等外部输入在测试边界注入，避免把真实服务可用性混入单元测试结果。

## 测试质量

好的测试在实现重构后仍成立，失败时能直接说明哪条行为不满足。它覆盖正常输出、边界值、错误/取消路径，以及共享 API 的兼容性。

行为变更的 test-first 纪律由 `CONV-TEST-FIRST` 定义。测试代码本身仍接受正常重构，但不能为掩盖产品行为回归而降低断言。

## 已知编译与运行陷阱

1. Swift Testing 的 `#expect` 会捕获表达式；mutating 调用先在宏外执行，把结果存入常量再断言。
2. Tuist `SettingsDictionary` 的值是 `SettingValue`。字符串字面量可推断，字符串变量需要显式类型，否则 manifest 编译失败。
3. App 测试会启动宿主。缺失 `-ObjC`、资源或初始化崩溃会表现为测试失败，这是有效的集成信号。
4. Simulator destination 使用 UDID 比设备名稳定；设备名可能在多个 runtime 中重复。

## UI 与并发测试关注点

SwiftUI 状态测试优先覆盖 model/state transition，再用少量 UI 测试验证系统整合。涉及 async/await 时测试完成、错误、取消和 actor 隔离，不用任意 sleep 代替可观察同步点。
