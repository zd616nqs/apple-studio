# 测试规范

本文说明:测试写在哪、怎么跑,以及本仓库实际踩过的几个坑。

## 原则

- **测行为,不测实现**:测试验证"输入什么、得到什么",不检查内部怎么实现的。
  实现重构后行为没变,测试就不应该跟着改
- **业务逻辑写成可以脱离界面测试的类型**:参考 DemoNotes 的 NotesStore——
  它是一个纯粹的结构体,增删逻辑不牵扯任何 UI,测试三行就能验证一条规则
- 单元测试目标由工厂默认生成(用 Swift Testing 框架);UI 测试成本高、易碎,
  默认不开,确有需要再显式开启
- Objective-C 代码同样从 Swift Testing 里测:共享模块直接 `import`,
  app 内部的类经测试目标的桥接头(见混编规范)

## 怎么跑

| 场景 | 命令 |
|---|---|
| 日常:只测受本次改动影响的 app | `./scripts/test-affected.sh` |
| 查看受影响范围(不跑测试) | `./scripts/test-affected.sh --list` |
| 指定比较基准 | `./scripts/test-affected.sh --base <ref>` |
| 手动全量测某个 app | `xcodebuild -workspace AppleStudio.xcworkspace -scheme <App> -destination 'platform=iOS Simulator,name=<设备名>' test`(设备名用 `xcrun simctl list devices available` 查;通常直接用 test-affected 即可,它会自动选) |

## 实际踩过的坑(勿再踩)

1. **`#expect` 宏里不要调用 mutating 方法**。Swift Testing 的 `#expect` 会把
   表达式包进一个不可变闭包,mutating 调用会编译报错("$0 is immutable")。
   正确写法:先在宏外面调用、结果存进 let 常量,再对常量断言
2. **Tuist 声明文件里的构建设置值不接受 String 变量**。`SettingsDictionary`
   的值类型是 `SettingValue`,字符串字面量能自动转换,但字符串**变量**不能——
   需要把变量显式声明为 `SettingValue` 类型,否则声明文件编译失败,
   而且报错藏在 tuist 的日志文件里,很难第一时间发现
3. **跑测试会真的启动 app**。测试宿主就是 app 本身,app 启动路径上的崩溃
   (比如缺 `-ObjC` 链接参数导致的分类方法崩溃)会让整个测试直接失败——
   这是特性不是缺陷:它替你发现了"编译通过但一运行就崩"的问题,不要绕过它
