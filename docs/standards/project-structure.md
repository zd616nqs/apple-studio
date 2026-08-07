# 工程结构规范

本文说明:这个仓库的工程是怎么组织的,新建一个 app 要做哪几步,共享代码放在哪里。

## 背景:为什么工程文件是"声明"出来的

传统 iOS 项目直接维护 .xcodeproj 文件,但它格式复杂、合并冲突频繁,AI 助手改起来极易出错。
本仓库改用 Tuist:每个 app 只写一份简短的 `Project.swift` 声明"我叫什么、依赖什么",
Xcode 工程由 `tuist generate` 现场生成。生成出来的 .xcodeproj / .xcworkspace 不进入版本管理,
也永远不要手工编辑——要改工程结构,改的是声明文件。

声明时不需要从零写配置:仓库提供了一个工厂
(`Tuist/ProjectDescriptionHelpers/Studio.swift`),把 bundle ID 前缀、系统版本要求、
测试配置这些全仓统一的约定都内置了,新 app 只需要"调用工厂 + 填空"。

## 新建一个 app(五步)

1. 新建 `Apps/<名字>/Project.swift`,内容就是调用一次工厂:
   `Studio.app(name: "...", destinations: ..., dependencies: [...])`
2. 按约定建目录:`Sources/`(代码)、`Resources/`(资源,把 PrivacyInfo.xcprivacy
   从示例 app 复制过来)、`Tests/`(测试)。目录名是固定约定,工厂按这些路径找文件
3. 如果是 Swift 和 Objective-C 混编的 app:工厂参数加 `hasObjC: true`,
   并创建两个桥接头文件 `Sources/BridgingHeader.h`、`Tests/BridgingHeader.h`
   (即使暂时是空的也必须存在,详见混编规范)
4. 建行为文档工作区:`(cd Apps/<名字> && mise exec -- openspec init --tools none)`,
   然后把 config.yaml 从示例 app 复制过来。**注意:config 里 rules 和 operations
   两段是全仓库统一的纪律,复制后不可删减,只允许改 context 段**(介绍本 app 的部分)
5. 运行 `mise exec -- tuist generate --no-open`,再跑 `./scripts/build-all.sh` 确认能构建

两个示例 app 就是模板:纯 Swift 的照抄 DemoNotes,混编的照抄 DemoPhotoMark。

## 工厂的固定约定

- 目录即约定:`Sources/**`、`Resources/**`、`Tests/**` 路径固定,不接受自定义
- 依赖共享模块只写 `Studio.sharedModule("模块名")`,不要自己拼相对路径
- 依赖第三方库只写 `.external(name: "库名")`,库的版本统一声明在 Tuist/Package.swift
- 系统版本要求:iOS 18 / macOS 15 起(全仓常量);个别 app 有特殊需求时用
  `deploymentTargets:` 参数覆盖
- 单元测试目标默认自动生成;UI 测试默认不生成,需要时加 `includeUITests: true`

## 共享层(Modules/)怎么组织

Modules/ 是一个共享工程,里面放多个 framework,当前有三个:

- FoundationKit / DesignKit:Swift 编写(Swift 6 语言模式)
- LegacyCore:Objective-C 编写

组织原则:

- **Swift 和 Objective-C 分开建 framework**,不在共享层混在一个目标里
  ——使用方通过 `import 模块名` 引用,干净且不需要桥接头
- **第二次需要才抽共享**:某段代码只有一个 app 用时就留在那个 app 里,
  第二个 app 也需要时才提取到 Modules/(避免过早抽象)
- 新增共享模块 = 在 `Modules/Project.swift` 里加一行 `Studio.module(name:lang:)`
  + 建源码目录
- Objective-C 模块必须有一个与模块同名的头文件(如 LegacyCore.h),
  模块的每个公开头文件都要手工 `#import` 进去——Swift 侧能否 import 这个模块,
  取决于这个总头文件(细节见混编规范)

## 改共享层的纪律

共享层被所有 app 依赖,改动要格外小心:

- 在专门的分支上做(分支名以 `change/modules-` 开头)
- 提交前运行 `./scripts/build-all.sh`,确认所有 app 依然能构建
- 公开接口尽量向后兼容:加新接口、标记旧接口废弃,而不是直接改签名删方法
