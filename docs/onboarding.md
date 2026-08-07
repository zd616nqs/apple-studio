# Onboarding：理解 apple-studio

apple-studio 是个人维护的 Apple 多 App monorepo。Tuist 让工程声明可读，OpenSpec 保存产品行为契约，脚本与 CI 把容易遗忘的检查变成可重复命令。Claude、Codex 和其他 Agent 都从同一个中立入口理解仓库。

这是一份给人读的心智模型，不是第二本规则手册。需要判断允许/禁止、变更等级或验证要求时，直接看根 `GOVERNANCE.md`。

## 第一次跑起来

```bash
brew install mise
scripts/bootstrap.sh
scripts/repo-doctor.sh
scripts/build-all.sh
```

生成后的 `AppleStudio.xcworkspace` 可以直接用 Xcode 打开。工程结构来自 `Project.swift`、`Workspace.swift`、`Tuist.swift` 和 `Tuist/`，所以 workspace/project 随时可以重建。

## 四类长期事实

| 问题 | 去哪里看 |
| --- | --- |
| 仓库怎样协作和验证 | `GOVERNANCE.md` |
| 工程有哪些 target、依赖和构建设置 | Tuist manifest 与 `Tuist/Package.swift` |
| main 当前有哪些可观察行为 | 各产品 store 的 `openspec/specs/` |
| 为什么采用某个难逆方案 | `docs/adr/` |

`RUNBOOK.md` 只负责命令和恢复，`docs/standards/` 只负责代码与工程领域的做法，App `CONTEXT.md` 只解释领域术语。一个文件有一个职责，阅读者不需要比较多份“哪份更权威”。

## 目录地图

```text
apple-studio/
├── GOVERNANCE.md                 中立治理源
├── AGENTS.md -> GOVERNANCE.md    Codex/通用 Agent 入口
├── CLAUDE.md -> GOVERNANCE.md    Claude 入口
├── CONTEXT.md                    治理术语
├── RUNBOOK.md                    命令与恢复
├── Apps/<App>/
│   ├── CONTEXT.md                App 领域术语
│   ├── Project.swift             App target 事实
│   └── openspec/                 正式行为与进行中 change
├── Modules/                      共享 framework 与共享行为
├── Tuist/                        工厂、依赖与工程 helper
├── docs/adr/                     决策原因
├── docs/standards/               工程领域规范
├── .governance/                  OpenSpec 原生 schema 适配
├── .agents/scratch/              ignored 中间产物
└── scripts/                      可执行入口
```

App 目录不再放 Agent 入口。这样会失去 Claude 在子目录自动注入局部说明的便利，但根入口会根据路径要求读取 App `CONTEXT.md`、`Project.swift` 和相关 specs；完整取舍记录在 ADR-0005/0006。

## 一个工作如何流动

开始时先在 `GOVERNANCE.md` 的决策表选择 direct、light-change、full-change 或 repo-change。Direct 是短路径；两类行为变更分别使用 OpenSpec 的轻量或完整 artifact 图；仓库架构决策保留 grill 记录和 ADR。

进行中的产品行为材料位于 store 的 `openspec/changes/<name>/`，完成并 archive 后更新正式 specs。未批准的调研、grill 中间材料、工具缓存与原型放 `.agents/scratch/<tool-or-task>/`。被接受的结果按含义进入 ADR、standards 或产品 specs，工具名不会变成长期目录分类。

本地 hook 提供快速反馈，repository doctor 给出统一健康报告，CI 对 main 给出最终结论。PR 先经过 Linux 静态检查；分类器只有在代码、共享层或工程配置受影响时才启动 Apple runner，最后由一个稳定的 `gate` 汇总结论。定时任务另跑当前 iOS 的全量构建与测试。三层的具体强度和规则 ID 只在 `GOVERNANCE.md` 定义。

## 示例工程在证明什么

- DemoNotes：纯 Swift/SwiftUI App 路径，以及 App 内状态与网络依赖示例。
- DemoPhotoMark：Swift/Objective-C 混编 App、桥接头、Objective-C 第三方库和图片处理示例。
- Modules：Swift 共享 framework 与 Objective-C framework 的集中声明方式。

支持状态不是愿望清单。`verified`、`committed`、`recognized` 的术语定义见 `CONTEXT.md`，当前清单和升级证据以 `GOVERNANCE.md` 为准。

## 扩展代码规范和个人 skill

项目特有且无法由原生 formatter 表达的真实规则，可以按工程关注点增加 `docs/standards/swift.md`、`objective-c.md`、`swiftui.md` 或 `concurrency.md`。没有真实规则时不建空文件。

个人 skill 的唯一源码位于 `.tooling/skills/`，Agent 入口使用相对链接。Skill 负责工作流和触发条件，工程规范仍留在 standards 或原生配置。接入命令、命名和冲突检查见 `RUNBOOK.md`。

## 推荐阅读顺序

1. `GOVERNANCE.md`：当前工作怎样分类、加载什么上下文、如何验收。
2. 当前 App 的 `CONTEXT.md`、`Project.swift` 和相关 specs。
3. 当前改动对应的 `docs/standards/`。
4. 需要执行命令或恢复环境时读 `RUNBOOK.md`。
5. 遇到意外设计时再读相关 ADR。
