# 测试规范

## 原则

- 只测外部行为,不测实现细节;好 seam 越高越好,数量越少越好
- 单元测试 target 默认生成(Swift Testing);UI 测试 opt-in,谨慎添加
- 核心逻辑写成可脱离 UI 测试的类型(参考 DemoNotes 的 NotesStore)
- ObjC API 从 Swift Testing 测(共享模块走 import,app 内类走 Tests/BridgingHeader.h)

## 命令

| 场景 | 命令 |
|---|---|
| 日常(只测受影响) | `./scripts/test-affected.sh` |
| skill 集成(拿受影响清单) | `./scripts/test-affected.sh --list` |
| 指定基准 | `./scripts/test-affected.sh --base <ref>` |
| 单 app 全测 | `xcodebuild -workspace AppleStudio.xcworkspace -scheme <App> -destination 'platform=iOS Simulator,name=<iPhone>' test`(设备名用 `xcrun simctl list devices available` 查;test-affected.sh 会自动挑,优先用它) |

## 已踩过的坑(实测,勿再踩)

1. **`#expect` 里不要调 mutating 方法**:宏把表达式包进不可变闭包,编译报 "$0 is immutable"。
   mutating 调用放宏外,结果存 let 再断言。
2. **Tuist manifest 的 SettingValue**:String 变量不会自动转换(字面量才会),
   需要显式 `let x: SettingValue = ...`,否则 manifest 编译失败且报错在 tuist 日志里。
3. **测试宿主会真的启动 app**:app 启动路径上的崩溃(如缺 -ObjC 的 category 崩溃)
   会让整个测试 run 失败——这是特性,别绕过它。
