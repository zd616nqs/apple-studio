# Swift 与 Objective-C 混编规范

本文说明:本仓库里 Swift 和 Objective-C 代码如何互相调用,以及编译器会替你把住哪些关。
背景:本仓库的 Objective-C 不是"只维护的遗留代码",而是会持续新写的一等公民,
所以混编的规矩必须清楚、且尽量交给编译器强制。

## 互相调用的两条通路(不要混用)

| 场景 | 用法 | 不要这样 |
|---|---|---|
| 调用共享层的 Objective-C 模块(如 LegacyCore) | Swift 里 `import LegacyCore`;Objective-C 里 `@import LegacyCore;` | 不要把共享模块的头文件塞进桥接头 |
| app 内部,Swift 调本 app 的 Objective-C 类 | 把头文件加进 `Sources/BridgingHeader.h`(工厂在 hasObjC 时自动挂载这个路径) | 不要试图跨 app/跨模块用桥接头 |

区分的原因:共享模块是独立编译的 framework,自带模块定义,`import` 即可,干净且低耦合;
桥接头是"同一个编译目标内部"让 Swift 看见 Objective-C 的机制,只适合 app 自己内部用。

测试也能直接测 Objective-C:测试目标有自己的桥接头(`Tests/BridgingHeader.h`),
把要测的类的头文件加进去,就能在 Swift Testing 里直接调用。

## 空值标注(nullability):编译器强制,不靠自觉

Objective-C 的指针默认"可能为 nil",Swift 那边就全变成拖泥带水的可选值,
还容易在运行时炸出空指针问题。所以本仓库要求所有 Objective-C 头文件明确标注空值性:

- 每个头文件用 `NS_ASSUME_NONNULL_BEGIN` / `END` 包住(默认一切不为空),
  确实可能为空的地方单独写 `nullable`
- **不标注 = 编译失败**,不是警告。工厂给所有 Objective-C 目标和混编 app
  都开了对应的编译开关,这条规矩由编译器执行,不需要人盯

## 语言模式:新旧代码分档

Swift 6 的严格并发检查对新代码是保护,对混编代码是一大笔迁移工作量。所以分两档:

- 纯 Swift 目标:Swift 6 语言模式(工厂默认)
- 混编 app 和 Objective-C 为主的目标:先用 Swift 5 模式,
  等该目标里 Objective-C 占比明显下降、或真的遇到并发问题时,再专门立变更去迁移

写代码前看清所在目标是哪一档(工厂参数 `hasObjC` 就是档位开关)。

## 一个隐蔽的链接陷阱(工厂已防,但要知道)

通过包管理器引入的 Objective-C 库,其"分类"(category,给已有类追加方法)有个特性:
如果代码里没有显式引用,链接器会把它整个丢弃——**编译完全正常,
运行时调用分类方法直接崩溃**(unrecognized selector)。

解决办法是给链接器加 `-ObjC` 参数强制保留所有分类。工厂在 `hasObjC` 开启时
自动加上这个参数,并且保证 app 自定义链接参数时也不会把它弄丢。
如果你绕过工厂手写工程配置,这个坑要自己记得填。
