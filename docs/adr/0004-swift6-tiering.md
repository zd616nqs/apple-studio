# ADR-0004 Swift 6 工具链,语言模式分档

- 状态:accepted(2026-08-06)
- 背景:Swift 6 严格并发对纯新代码是净收益,对 ObjC 密集/混编代码是迁移税;
  本仓 ObjC 仍大量新写。

## 决策

- 工具链统一 Swift 6;纯 Swift 新 target 一律 6 语言模式(工厂默认)
- hasObjC app 与 ObjC 密集 target 先 5 模式,并发债务显式留在这些 target 内
- 迁移时机:某混编 target 的 ObjC 占比明显下降、或并发 bug 实际出现时,开 change 翻开关

## 后果

- ✅ 新代码享受严格并发检查;混编路线不被并发迁移阻塞
- ⚠️ 两种语言模式并存,写代码前看清所在 target 的档位(工厂参数即档位声明)
