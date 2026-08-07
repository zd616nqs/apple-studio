# apple-studio — Apple 生态 monorepo

会话永远开在仓库根目录(本文件所在层)。Codex 经 AGENTS.md 软链读到同一份规则,skills 经 .agents/skills 软链共读。

## 红线(所有 agent、所有分支适用)

1. 生成物不入库、不手改:.xcodeproj / .xcworkspace 由 Tuist 生成,唯一事实来源是声明文件(manifest)。明文例外:Tuist/Package.resolved 必须入库。
2. 三方依赖只在 Tuist/Package.swift 声明(单一版本策略);app 和模块用 `.external(name:)` 引用,禁止私加依赖。
3. 共享层(Modules/)改动只在 `change/modules-*` 分支进行;影响所有 app,提交前必跑 `scripts/build-all.sh`。
4. OpenSpec:禁 `/opsx:ff`(本仓未装,禁止安装);archive 在 feature 分支上执行、与合并绑定;未合并分支禁 `/opsx:sync`;行为变更必须回写 spec。
5. >5MB 文件不入库(pre-commit 强制)。Secrets 类文件对 agent 禁读禁写。
6. 零全局状态:任何脚本 / agent 不得写 home 或系统目录配置;一切配置只进本仓库。
7. git:1 change = 1 branch,分支名 `change/<app>-<slug>`(`<app>` 全小写同 commit scope,`<slug>` kebab-case 动宾短语,如 `change/demonotes-delete-note`);conventional commits(`feat(demonotes): …`)。合并 / tag / 分支保留纪律见 RUNBOOK §3(单一来源)。
8. 产物落点:仓库根禁止新建文档、禁止 `openspec new`(会静默自建 root store);openspec 命令必须在 store 目录执行;未立项产物一律写 `.agents/scratch/`(gitignored),立项后随 propose 迁入 change 容器。

## 变更路由(判断先于动手)

- 琐碎非行为改动 → 直接改
- 小的行为变更 → openspec propose
- 技术不确定 → 先探索原型,再 propose
- 产品级 / 不可逆 / 共享模块 / 跨 app → grill-with-docs 盘问后新开 change

## 目录路由表(按需加载,不要全量读)

| 路径 | 内容 | 细则入口 |
|---|---|---|
| Apps/<Name>/ | 单个 app(业务只存在于此) | Apps/<Name>/CLAUDE.md + CONTEXT.md |
| Modules/ | 共享层:一个共享工程,集中声明多个 framework | docs/standards/project-structure.md |
| Tuist/ | Studio 工厂 + 全仓依赖声明 | Tuist/ProjectDescriptionHelpers/Studio.swift |
| scripts/ | 全部自动化入口 | 下表 |
| docs/onboarding.md | 新人手册(结构/流程/检查机制全景) | 首次接触从这读起 |
| docs/adr/ | 生态级决策与已接受风险 | 0001-0005 首批 |
| docs/standards/ | 结构/混编/依赖/测试四份规范 | 改代码前按需读对应篇 |
| openspec(各 store) | 已合并行为的活文档 | `(cd Apps/<App> && mise exec -- openspec …)` |
| RUNBOOK.md | 日常流程 / 回归 / 故障排查 | 变更标准流程在 §3 |
| .claude/skills/ | 仓库级 skills(双工具共读) | apple-api-lookup:API 查询优先级 |
| .agents/scratch/ | 暂存区(gitignored) | 未立项产物默认落此 |

## 脚本

| 脚本 | 用途 |
|---|---|
| scripts/bootstrap.sh | clone 后一键完成环境配置 |
| scripts/build-all.sh | 生成 + 构建全部 app(共享层改动后必跑) |
| scripts/test-affected.sh | 只测受影响范围;`--list` 出 JSON 供 skill 消费 |
| scripts/openspec-update-all.sh | OpenSpec 升级后刷新工具文件 + store 检查 |
| scripts/beta-smoke.sh | beta Xcode 快速构建验证(不阻塞) |

## OpenSpec 入口(按客户端)

Claude = `/opsx:*` 命令;Codex = `$openspec-*` skills;其他客户端照 `.claude/skills/openspec-*/SKILL.md` 用 CLI 手跑。不用 `openspec store` 全局注册,一律在 store 目录内就近发现。

## 工具链

mise.toml 锁定 Tuist / openspec 版本,.xcode-version 锁定 Xcode;升级走 change 分支 + build-all 全部通过。
