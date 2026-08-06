# Tasks: delete-note

## 1. TDD 实现(先红后绿)

- [x] 1.1 DemoNotesTests.swift 新增删除行为测试(删除存在项、删除不存在项无副作用、删除后可重加同内容;mutating 调用放 #expect 外)——先跑确认红
- [x] 1.2 NotesStore 新增按内容删除方法(与 add 对称,内存态)
- [x] 1.3 ContentView 列表接平台标准左滑删除手势
- [x] 1.4 无新增文件则免 generate;若加了文件先跑 `mise exec -- tuist generate --no-open`

## 2. 验证

- [x] 2.1 `./scripts/test-affected.sh --list` 确认只报 DemoNotes
- [x] 2.2 `./scripts/test-affected.sh` 全绿(新旧测试都过)
- [x] 2.3 更新本 store CONTEXT.md 术语表(NotesStore 描述补删除语义)

## 3. 收尾(archive 前置于合并)

- [x] 3.1 本分支上执行 archive(specs/note-management 落成主 spec;红线 4:禁 ff)
- [x] 3.2 conventional commit `feat(demonotes): 支持删除笔记`,过 pre-commit
- [x] 3.3 rebase main → merge --no-ff → push(不打 tag:合并 ≠ 发版)

## 回滚

- revert 合并提交即可(单 commit 变更;specs 回滚随 revert 一起,内存态无数据迁移)
