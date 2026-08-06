# apple-studio — Apple 生态 monorepo

会话永远开在仓库根目录(本文件所在层)。Codex 经 AGENTS.md 软链读到同一份规则,skills 经 .agents/skills 软链共读。

## 红线(所有 agent、所有分支适用)

1. 生成物不入库、不手改:.xcodeproj / .xcworkspace 由 Tuist 生成,唯一真相是 manifest(Project.swift / Workspace.swift / Tuist/)。
2. 三方依赖只在 Tuist/Package.swift 声明(单一版本策略);app 和模块用 `.external(name:)` 引用,禁止绕过此文件私加依赖。
3. 共享层(Modules/)改动只在 `change/modules-*` 分支进行;影响所有 app,提交前必跑 `scripts/build-all.sh`。
4. OpenSpec:禁用 `/opsx:ff`(上游 stale-specs bug);archive 在 feature 分支上执行、与代码同 PR 合并;未合并分支禁 `/opsx:sync`;行为变更必须回写 spec。
5. >5MB 文件不入库(pre-commit 强制拦截)。Secrets 类文件对 agent 禁读禁写。
6. 零全局状态:任何脚本 / agent 不得写 home 或系统目录配置(~/.claude/、~/.codex/ 等);一切配置只进本仓库。
7. git:1 change = 1 branch = 1 PR,分支名 `change/<app>-<slug>`;conventional commits(`feat(demonotes): …`);发版 tag 格式 `App-<Name>-1.1.3`。

## 变更路由(判断先于动手)

- 琐碎非行为改动 → 直接改
- 小的行为变更 → openspec propose
- 技术不确定 → 先探索原型,再 propose
- 产品级 / 不可逆 / 共享模块 / 跨 app → grill-with-docs 盘问后新开 change

## 目录路由表(按需加载,不要全量读)

| 路径 | 内容 | 细则入口 |
|---|---|---|
| Apps/<Name>/ | 单个 app(业务只存在于此) | Apps/<Name>/CLAUDE.md |
| Modules/ | 共享层:伞形 Project、多 framework target | (ticket 02 起) |
| Tuist/ | Studio 工厂 + 全仓依赖声明 | Tuist/ProjectDescriptionHelpers/Studio.swift |
| scripts/ | 全部自动化入口 | 下表 |
| docs/ | ADR / 标准 / RUNBOOK | (ticket 07 起) |
| openspec(各 store) | 已合并行为的活文档 | (ticket 06 起) |
| .agents/scratch/ | 暂存区(gitignored) | 未立项产物默认落此 |

## 脚本

| 脚本 | 用途 |
|---|---|
| scripts/bootstrap.sh | clone 后一条命令跑通环境(mise 钉版安装、git hooks、tuist install) |
| scripts/build-all.sh | 生成 workspace 并构建全部 app(共享层改动后必跑) |
| scripts/test-affected.sh | (ticket 05)只测受影响范围;`--list` 输出 JSON 供 skill 消费 |

## 工具链

mise.toml 钉 Tuist 与 openspec CLI 版本,.xcode-version 钉 Xcode。工具链升级一律走 change 分支 + build-all 全绿后合并。
