# ADR-0002 单一版本策略

- 状态:accepted(2026-08-06)
- 背景:本地路径依赖(Tuist target / local SPM package)没有版本概念,
  "共享层多版本共存"在 monorepo 里没有廉价实现。

## 决策

- 全仓任意时刻只有一个版本的共享层与三方依赖(Tuist/Package.swift exact 钉版)
- 发版 tag `App-<Name>-x.y.z` = 全树快照;"旧版本共存"由 git 提供:从 tag 拉 hotfix 分支
- 共享层公开 API 默认后向兼容(加新标废弃,不改签名);破坏性变更一次迁完所有 app

## 后果

- ✅ 永无依赖漂移;没有版本矩阵要维护(solo 开发者最大成本项被删除)
- ⚠️ 共享层破坏性变更成本前置(必须当场迁完);由 rule of two + 后向兼容纪律缓解
