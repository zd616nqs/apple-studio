# 混编规范(Swift + ObjC)

## 两条通路,不要混

| 场景 | 通路 | 禁止 |
|---|---|---|
| 消费共享 ObjC 模块(LegacyCore 等) | `import LegacyCore` / `@import LegacyCore;`(module import) | 把共享模块头塞进桥接头 |
| app target 内 Swift 看本 target ObjC | `Sources/BridgingHeader.h`(工厂 hasObjC 自动挂) | 跨 target 用桥接头 |

测试 target 经 `Tests/BridgingHeader.h` 直测 app 内 ObjC 类(符号运行时由宿主 app 提供)。

## nullability 门禁(工厂 objcQualityGate,自动生效)

- 所有 ObjC 头文件用 `NS_ASSUME_NONNULL_BEGIN/END` 包裹,例外处显式 `nullable`
- 头文件缺注解 = 编译失败(`-Werror=nullability-completeness`),不是警告
- 转换违规同样升 error(`CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION=YES_ERROR`)

## 语言模式分档

- 纯 Swift target:Swift 6 语言模式(严格并发)
- `hasObjC` app / ObjC 密集 target:先 Swift 5 模式,逐步迁移,迁完翻开关

## 链接陷阱(工厂已防,绕过工厂自负)

SPM 静态库里的 ObjC category 不被显式引用会被 linker 丢弃:编译全绿、运行期
`unrecognized selector`。工厂在 hasObjC 时强制追加 `-ObjC`(自定义 OTHER_LDFLAGS 也不会丢)。
