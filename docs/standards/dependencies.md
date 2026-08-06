# 依赖管理

## 单一版本策略(ADR-0002)

- 全仓三方依赖只在 `Tuist/Package.swift` 声明,exact 钉版;`Tuist/Package.resolved` 入库
- app / 模块侧只允许 `.external(name:)` 引用;任何绕过集中声明的私加依赖都是红线 2 违规
- 本地共享模块没有版本号;"某 app 用旧版共享层" = 从发版 tag(`App-<Name>-x.y.z`,全树快照)拉分支

## 升级依赖

1. 开 `change/deps-<slug>` 分支,只改 Tuist/Package.swift
2. `mise exec -- tuist install && ./scripts/build-all.sh` + 受影响 app 测试全绿
3. 一库一变更;大版本升级读上游 CHANGELOG 后再动

## pods-only 三方 SDK 例外(三级递进,当前未启用)

仅当 SDK 只发 CocoaPods 时:
1. **adapter 隔离**:SDK 只被一个薄 adapter 模块引用,业务代码零直接 import
2. **XCFramework 预打包**:pod 侧产物打成 XCFramework 进仓/进制品库,主工程无 pod 依赖
3. **内化**:SDK 停更或成本过高时,fork/替换/自实现

## 工具链也是依赖

Tuist / openspec CLI 由 mise.toml 钉版,Xcode 由 .xcode-version 钉版;
升级 = change 分支 + build-all 全绿,禁止顺手升级。
