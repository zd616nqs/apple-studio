# 工程结构与工厂用法

## 新建 app 清单(分钟级)

1. `Apps/<Name>/Project.swift`:调 `Studio.app(name:destinations:dependencies:…)`
2. 建约定目录:`Sources/`、`Resources/`(放 PrivacyInfo.xcprivacy,从 demo 复制)、`Tests/`
3. 混编 app:`hasObjC: true` + 两个桥接头文件(`Sources/BridgingHeader.h`、`Tests/BridgingHeader.h`,可为空但必须存在)
4. `(cd Apps/<Name> && openspec init --tools none)` 建行为文档 store,config.yaml 从 demo 复制;
   **rules/operations 段是仓库纪律(含红灯确认/断言冻结/archive 红线),复制后不可删减,只允许改 context 段**
5. `mise exec -- tuist generate --no-open` → `./scripts/build-all.sh`

## 工厂约定(Tuist/ProjectDescriptionHelpers/Studio.swift)

- 目录即约定:`Sources/**`、`Resources/**`、`Tests/**` 固定,不接受自定义 glob
- 共享模块依赖只写 `Studio.sharedModule("Name")`,不手写 `.project(path:)`
- 三方库只写 `.external(name:)`,声明一律在 Tuist/Package.swift
- 部署目标:iOS 18 / macOS 15 常量,按 destinations 推导;特例走 `deploymentTargets:` 参数
- 单元测试 target 默认生成;UI 测试 `includeUITests: true` 显式开

## 共享层(Modules/)

- 一个 Project 多 framework target;语言隔离(Swift 与 ObjC 分 target)
- 新共享模块 = `Studio.module(name:lang:)` 一行 + 源码目录;rule of two:第二个 app 需要时才抽共享
- ObjC 模块必须有同名伞头(如 LegacyCore.h),新公开头文件手动 #import 进伞头
