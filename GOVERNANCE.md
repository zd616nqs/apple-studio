# apple-studio repository governance

本文件是仓库治理规则的唯一人工维护来源。`AGENTS.md` 与 `CLAUDE.md` 必须是指向本文件的相对软链。工具配置、hook、脚本和 CI 只实现下列规则并引用规则 ID，不得另写一套政策。

会话必须将 `apple-studio` 本身作为 workspace 根目录。治理术语见 `CONTEXT.md`；操作命令与故障恢复见 `RUNBOOK.md`；决策原因见 `docs/adr/`。

## 规则强度

- **Gate**：违反即失败，必须有机器验证入口。
- **Check**：自动报告，允许提交者说明理由后继续，不改变退出码冒充 Gate。
- **Convention**：人和 Agent 的默认做法，不声称机器强制。

## 开始工作：先分类

Agent 在修改前必须说明命中的条件。边界不清时升级；维护者可以显式覆盖分类。

| 等级 | 确定条件 | 流程 |
| --- | --- | --- |
| `direct` | 不改变可观察行为；机械调整、注释、格式或普通可逆工具修复 | 修改 → 相应验证 → doctor/CI |
| `light-change` | 单 App、可逆，且不涉及共享层、迁移、隐私、安全或不可逆影响 | OpenSpec `light-change` → apply → archive |
| `full-change` | 共享层、跨 App、迁移、隐私、安全、不可逆，或边界不清 | OpenSpec `full-change` → apply → archive |
| `repo-change` | 治理、CI 或工具架构的难逆决策 | grill-with-docs → ADR → `change/repo-*` → doctor/CI |

OpenSpec 只管理产品行为。仓库治理不创建第四个 store。产品 store 默认 `full-change`；只有明确命中轻量条件时才显式选择 `light-change`。

## 按路径加载上下文

只读取当前任务需要的材料，不全量加载仓库文档。

| 触及范围 | 必须读取 |
| --- | --- |
| 治理术语或规则 | `CONTEXT.md`、本文件；难逆原因再读相关 ADR |
| `Apps/<App>/` | 该 App 的 `CONTEXT.md` 与 `Project.swift` |
| App 可观察行为 | 上一行，加该 store 中相关 `openspec/specs/`；变更材料留在该 store |
| `Modules/` | `Modules/Project.swift`、相关实现、相关 `docs/standards/` 与 `Modules/openspec/specs/` |
| `Tuist/`、manifest、依赖 | `Tuist/ProjectDescriptionHelpers/Studio.swift`、`Tuist/Package.swift`、相关工程标准 |
| Swift / Objective-C / SwiftUI / 并发 / 测试 | `docs/standards/` 中对应主题；原生 formatter 配置优先于 prose |
| 脚本、hook、CI 或故障恢复 | `RUNBOOK.md` 与被修改入口本身 |

App 的依赖与 target 事实以 `Project.swift` 为准；第三方版本以 `Tuist/Package.swift` 为准；命令参数以 `--help` 为准。上下文文档不缓存这些事实。

## Gate 注册表

| ID | 适用范围与规则 | 验证入口 |
| --- | --- | --- |
| `GATE-ROOT-ALLOWLIST` | tracked 根目录 entry 只能来自下方清单 | pre-commit；`repo-doctor.sh --static`；CI static |
| `GATE-GENERATED-FILES` | `.xcodeproj`、`.xcworkspace`、Derived/DerivedData 等生成物不得 tracked 或 staged；`Tuist/Package.resolved` 是明确例外 | pre-commit；doctor static；CI static |
| `GATE-SECRETS` | Secret、本地凭据和 `*.secrets.*` 不得 stored、staged 或 tracked | pre-commit；doctor static；CI static |
| `GATE-LARGE-FILES` | staged/tracked blob 不得超过 5 MiB | pre-commit；doctor static；CI static |
| `GATE-DEPENDENCY-SOURCE` | 第三方依赖只在 `Tuist/Package.swift` 声明；App/Modules 仅按名称引用 | pre-commit；doctor static；CI static |
| `GATE-AGENT-ENTRY` | 根 Agent 入口、schema 与个人 skill 链接必须完整、相对且解析到仓库内唯一源 | doctor static；CI static |
| `GATE-OPENSPEC-SCHEMA` | 只能有 `light-change`、`full-change` 两套 schema；三个 store 都必须解析和 validate | doctor static；OpenSpec CLI；CI static |
| `GATE-TOOLCHAIN-VERSION` | Node、OpenSpec、Tuist、Xcode version/build 必须匹配 `mise.toml` 与两个 Xcode lock | doctor（local/CI）；CI apple |
| `GATE-REQUIRED-VERIFICATION` | App、Modules、Tuist 改动必须执行由影响面决定的生成、构建和测试 | `test-affected.sh`、`build-all.sh`、doctor；CI apple |
| `GATE-DIRECT-MAIN` | 正常本地提交不得落在 `main`；应急提交必须有非空 `Break-Glass:` trailer | commit-msg hook |
| `GATE-MAIN-CI` | main 合并必须通过远端稳定的最终 `gate` | CI `gate`；GitHub branch protection |

`GATE-SECRETS` 的机器边界是仓库内容。所有 Agent 都不应被要求读取或写入 Secret；Claude 适配另有 read/write deny，Codex 当前没有等价客户端能力，不能把 Git/CI 描述为通用防读保护。

允许的 tracked root entry 固定为：

```text
.agents  .claude  .github  .githooks  .governance  .tooling
Apps  Modules  Tuist  docs  scripts
.gitignore  .swift-format  .xcode-version  .xcode-build-version
AGENTS.md  CLAUDE.md  GOVERNANCE.md  CONTEXT.md  RUNBOOK.md
Workspace.swift  Tuist.swift  mise.toml
```

`.git` 由 Git 管理；`.DS_Store` 与生成 project/workspace 只能 ignored/untracked。新增 root entry 必须先用 repo change 修改本清单。不存在 `GATE-GOVERNANCE-DRIFT`：OpenSpec schema 只有一个物理源，doctor 检查链接结构而非比较副本。

## Check 注册表

| ID | 适用范围与检查 | 报告入口 |
| --- | --- | --- |
| `CHECK-BRANCH-NAME` | 分支是否符合 `change/<scope>-<verb-object>` 并匹配范围 | pre-commit / review |
| `CHECK-COMMIT-FORMAT` | 提交是否符合 conventional commits | commit-msg / review |
| `CHECK-SWIFT-FORMAT` | Swift 是否符合 `.swift-format` | pre-commit / CI report |
| `CHECK-CHANGE-TIER` | direct/light/full/repo 分类是否命中决策表 | Agent 声明 / review |
| `CHECK-SHARED-API-COMPATIBILITY` | 共享公开 API 是否有破坏性变化 | review / API 工具（存在时） |
| `CHECK-GOVERNANCE-SIZE` | 报告本文件 bytes/lines；超过 16 KiB 或 240 行时警告 | doctor static |
| `CHECK-BREAK-GLASS-REASON` | 本地绕过是否留下具体、非空原因 | commit-msg / review |

## Convention 注册表

| ID | 适用范围与约定 | 复核入口 |
| --- | --- | --- |
| `CONV-ROOT-WORKSPACE` | Agent 从本仓库根启动 | 会话启动时人工确认 |
| `CONV-ONE-ACTIVE-CHANGE` | 个人主力开发一次推进一个 change | 维护者工作流 |
| `CONV-NO-FF-MERGE` | change 分支使用 `--no-ff` 合并 | merge review |
| `CONV-BRANCH-RETENTION` | 合并后由维护者手工决定是否删除 change 分支 | merge 后人工维护 |
| `CONV-SECOND-USE-SHARING` | 第二次真实复用时再抽共享能力 | design review |
| `CONV-TEST-FIRST` | 行为变更先观察与预期原因一致的失败测试；只有 spec 改变才调整已确认断言 | change review |
| `CONV-OPENSPEC-ARCHIVE` | 同一 change 分支完成验证与 archive，让代码与正式 spec 经同一 PR 合并 | OpenSpec archive / PR review |

## 分支与提交

分支格式为 `change/<scope>-<verb-object>`；合法 scope 是 `repo`、`modules` 或 App 目录名小写。普通提交使用 conventional commits。一次 change 对应一个 branch 和一个 PR。

本地应急 trailer 格式：

```text
Break-Glass: <具体、非空原因>
```

`--no-verify` 不能从 Git 机制消失；它不改变 CI Gate，也不赋予直推 main 的权限。合并后的 change 分支默认保留，直到维护者手工清理。

## OpenSpec、工具产物与 skills

- 唯一 schema 源是 `.governance/openspec/schemas/{light-change,full-change}`；store 只通过相对目录软链消费。
- `light-change` 的 artifact DAG 是 `specs`；`full-change` 是 `proposal → specs → design → tasks`。OpenSpec operation 只使用 apply/archive。
- Store config 只保留 store 上下文、默认 schema 与 archive 规则 ID 指针，不复制共享政策。
- 未批准的调研、grill、原型和工具中间产物进入 ignored `.agents/scratch/<tool-or-task>/`。
- 已接受资产按语义进入 `docs/adr/`、`docs/standards/` 或 `docs/onboarding.md`；工具名不拥有长期文档目录。
- 首个真实个人 skill 才创建 `.tooling/skills/<kebab-case-name>/` 唯一源码，并用相对链接暴露给 Agent；`openspec-` 是保留前缀。
- 工程风格权威顺序是原生配置（如 `.swift-format`）> `docs/standards/` > skill 工作流建议。

OpenSpec 的退出成本必须有界：generate/build/test 不依赖 OpenSpec，正式 spec 保持可读 Markdown，产品代码与测试接口不引用 OpenSpec 类型。真正退出时再单次迁移 Markdown，不预先维护第二棵 Specs 树。

## 平台与产品目标状态

- **verified**：已有 factory、示例、构建和测试证据。目前是 iOS/iPadOS App、纯 Swift App、Swift/Objective-C 混编 App。
- **committed**：进入路线图但当前不可宣称可用。App 为 macOS、tvOS、iPhone companion watchOS；产品目标为 WidgetKit、Share、Notification Service、Notification Content、App Intents、TV Top Shelf、AutoFill Credential Provider、Call Directory/Message Filter、Network、Device Activity、iMessage。
- **recognized**：已知存在但没有支持承诺。其余 Extension 属于此状态，不提前设计通用 factory。

## 完成声明

在声称工作完成前：运行 `scripts/repo-doctor.sh` 的适用模式；运行影响面要求的 build/test；行为变更 validate 并 archive 对应 OpenSpec change；确认 `git diff --check` 与 `git status`；报告未执行项及原因。CI 是 main 的最终权威。
