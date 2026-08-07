# ADR-0001 Tuist 作为唯一工程生成器与依赖图权威

- 状态:accepted(2026-08-06,建仓即生效)
- 背景:多 app + 共享层 + 混编(ObjC 量大),agent 高频改工程结构;pbxproj 手管不可维护。
  早期调研曾倾向 XcodeGen,用户自行深入调研后推翻(handoff:/private/tmp/tuist-monorepo-handoff.md)。

## 决策

Tuist 管 workspace/工程/依赖图,manifest 是唯一事实来源,生成物不入库。
SwiftPM(Tuist/Package.swift)管三方依赖。共享层用 Tuist 原生 target
(支持单 target 混编,绕开 SPM SE-0403 单语言限制)。

## 后果

- ✅ 新 app 分钟级;依赖图可查询(test-affected 反查);pbxproj 冲突消失
- ⚠️ 接受 Tuist 升级追赶负担(ADR-0005 风险 1);Xcode 大版本发布初期可能等 Tuist 适配
- ⚠️ 工厂(Studio.swift)成为单点约定,改动属共享区,走 change/modules-* 纪律
