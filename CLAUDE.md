# apple-studio — Apple 生态 monorepo

会话永远开在仓库根目录(本文件所在层)。Codex 经 AGENTS.md 软链读到同一份规则,skills 经 .agents/skills 软链共读。

## 红线(所有 agent、所有分支适用)

1. 生成物不入库、不手改:.xcodeproj / .xcworkspace 由 Tuist 生成,唯一真相是 manifest(Project.swift / Workspace.swift / Tuist/)。明文例外:Tuist/Package.resolved 锁文件必须入库(单一版本策略的落地凭证)。
2. 三方依赖只在 Tuist/Package.swift 声明(单一版本策略);app 和模块用 `.external(name:)` 引用,禁止绕过此文件私加依赖。
3. 共享层(Modules/)改动只在 `change/modules-*` 分支进行;影响所有 app,提交前必跑 `scripts/build-all.sh`。
4. OpenSpec:禁用 `/opsx:ff`(上游 OpenSpec 的快捷命令,本仓未安装且禁止安装使用——stale-specs bug);archive 在 feature 分支上执行、与代码合并动作绑定;未合并分支禁 `/opsx:sync`;行为变更必须回写 spec。
5. >5MB 文件不入库(pre-commit 强制拦截)。Secrets 类文件对 agent 禁读禁写。
6. 零全局状态:任何脚本 / agent 不得写 home 或系统目录配置(~/.claude/、~/.codex/ 等);一切配置只进本仓库。
7. git:1 change = 1 branch,分支名 `change/<app>-<slug>`(`<app>` 全小写同 commit scope,`<slug>` kebab-case 动宾短语,如 `change/demonotes-delete-note`);conventional commits(`feat(demonotes): …`);solo 默认本地 rebase main → `merge --no-ff` → push,**合并后保留 change 分支**;tag 格式 `App-<Name>-1.1.3`,**只在真正发版时打,合并 ≠ 发版**。
8. 产物落点:仓库根**禁止**新建文档/新开 openspec change——`openspec new` 在根目录会静默自建 root store(pre-commit 会拒绝其入库),必须 `(cd Apps/<App> && …)` 在 store 内执行;grill/brainstorm/调研等**未立项产物一律写 `.agents/scratch/`**(gitignored),立项后随 propose 迁入对应 store 的 change 容器。

## 变更路由(判断先于动手)

- 琐碎非行为改动 → 直接改
- 小的行为变更 → openspec propose
- 技术不确定 → 先探索原型,再 propose
- 产品级 / 不可逆 / 共享模块 / 跨 app → grill-with-docs 盘问后新开 change

## 目录路由表(按需加载,不要全量读)

| 路径 | 内容 | 细则入口 |
|---|---|---|
| Apps/<Name>/ | 单个 app(业务只存在于此) | Apps/<Name>/CLAUDE.md + CONTEXT.md |
| Modules/ | 共享层:伞形 Project、多 framework target | docs/standards/project-structure.md |
| Tuist/ | Studio 工厂 + 全仓依赖声明 | Tuist/ProjectDescriptionHelpers/Studio.swift |
| scripts/ | 全部自动化入口 | 下表 |
| docs/adr/ | 生态级决策与已接受风险 | 0001-0005 首批 |
| docs/standards/ | 结构/混编/依赖/测试四份规范 | 改代码前按需读对应篇 |
| openspec(各 store) | 已合并行为的活文档 | 命令在 store 目录执行:`(cd Apps/<App> && mise exec -- openspec …)` |
| RUNBOOK.md | 回归/换机/故障排查 | 三个月不碰后从这读起 |
| .agents/scratch/ | 暂存区(gitignored) | 未立项产物默认落此 |

## 脚本

| 脚本 | 用途 |
|---|---|
| scripts/bootstrap.sh | clone 后一条命令跑通环境(mise 钉版安装、git hooks、tuist install) |
| scripts/build-all.sh | 生成 workspace 并构建全部 app(共享层改动后必跑) |
| scripts/test-affected.sh | 只测受影响范围(diff 分类 + tuist graph 反查);`--list` 输出 JSON 供 skill 消费 |
| scripts/openspec-update-all.sh | OpenSpec 升级后:重生成根工具文件 + 各 store 健康检查 |
| scripts/beta-smoke.sh | beta Xcode 全量构建冒烟(非阻塞、一次性缓存) |

## OpenSpec 工作流入口(按客户端)

- Claude Code:`/opsx:propose` 等斜杠命令(.claude/commands/opsx/)
- Codex:`$openspec-propose` 等 skills(经 .agents/skills 软链)
- 其他 AGENTS.md 系客户端:照 `.claude/skills/openspec-*/SKILL.md` 的流程直接用 `mise exec -- openspec` CLI 手跑
- 本仓**不使用** `openspec store` 全局注册机制,一律靠"在 store 目录内执行"的就近发现

## 工具链

mise.toml 钉 Tuist 与 openspec CLI 版本,.xcode-version 钉 Xcode。工具链升级一律走 change 分支 + build-all 全绿后合并。
