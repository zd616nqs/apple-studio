# Proposal: delete-note

## Why

DemoNotes 目前只能添加笔记,列表会无限增长;作为「纯 Swift 活范例」它也缺一个展示
SwiftUI 列表删除交互 + 可测业务逻辑的样例。本 change 同时是仓库工作流的首次全流程验证。

## What Changes

- NotesStore 新增按内容删除笔记的能力(内存态,与现有 add 对称)
- 笔记列表支持 iOS 惯例的左滑删除(假设记录:交互形态取平台标准 swipe-to-delete,
  不做确认弹窗——内存 demo 数据无不可逆风险)
- 无破坏性变更;add 行为不变

## Capabilities

### New Capabilities

- `note-management`: 笔记的增删管理(内存态):添加时清洗与去重(现有行为首次成文)、按内容删除

### Modified Capabilities

(无——本 store 尚无已归档 capability,现有 add 行为随本 change 一并成文进 note-management)

## Impact

- 受影响 app:仅 DemoNotes;不涉及共享模块(Modules/ 零改动)
- 依赖图变更:无(不新增 target/依赖边/三方库)
- 代码面:NotesStore.swift(逻辑)、ContentView.swift(列表交互)、DemoNotesTests.swift(新增测试)
- 验证:scripts/test-affected.sh(预期只报 DemoNotes);回滚 = revert 本分支合并提交
