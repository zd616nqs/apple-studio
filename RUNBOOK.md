# RUNBOOK — 三个月不碰之后,十分钟回到工作状态

## 0. 这个仓库是什么

Apple 生态 monorepo:Tuist 管工程,多 app + 共享层 Modules,OpenSpec 管行为文档,
双 agent(Claude Code / Codex)开发。规则唯一入口:根 [CLAUDE.md](CLAUDE.md)。

## 1. 环境重建(换机器 / 重装后)

```bash
brew install mise        # 若 mise 不在
./scripts/bootstrap.sh   # mise 钉版安装 Tuist/openspec、启用 git hooks、解析依赖、生成 workspace
./scripts/build-all.sh   # 全部 app 构建,全绿即环境健康
```

## 2. 日常命令速查

| 要做什么 | 命令 |
|---|---|
| 改了共享层,验证所有 app | `./scripts/build-all.sh` |
| 只测受影响范围 | `./scripts/test-affected.sh`(`--list` 出 JSON) |
| 工程文件变了(加文件/改依赖) | `mise exec -- tuist generate --no-open` |
| OpenSpec 升级后 | `./scripts/openspec-update-all.sh` |
| 看某 app 的行为文档/变更 | `(cd Apps/<App> && mise exec -- openspec status)` |

## 3. 开发一个变更(标准流程)

1. 判断级别(根 CLAUDE.md「变更路由」):琐碎→直接改;行为变更→`/opsx:propose`
2. 开分支 `change/<app>-<slug>`(共享层 = `change/modules-<slug>`)
3. TDD 实现 → `./scripts/test-affected.sh` 绿
4. 行为变更在**本分支**上 `/opsx:archive`(红线 4:禁 ff、未合并禁 sync)
5. rebase main → merge --no-ff → push;**合并后保留 change 分支**(本地+远端都留,不删);**只在真正发版时**打 tag `App-<Name>-x.y.z`(日常合并不打)

## 4. 常见故障

- **tuist 命令找不到** → 没装 mise 或没跑 bootstrap;脚本都走 `mise exec --`,不要全局装 tuist
- **tuist generate 报 manifest 编译错** → 看 `~/.local/state/tuist/sessions/…/logs.txt`;常见坑:SettingValue 不吃 String 变量(docs/standards/testing.md 陷阱清单)
- **混编 app 运行期 unrecognized selector** → 检查 `-ObjC` 旗标没被自定义 settings 冲掉(工厂已防,若绕过工厂则自查)
- **Xcode 升级后构建怪异** → 对照 `.xcode-version`;beta 只走 beta-smoke 通道,别把日常构建切到 beta
- **pre-commit 拦了我** → 看它打印的红线编号;确认误报可 `git commit --no-verify`(逃生通道,事后补救)

## 5. 别忘了

- 工具链升级(Tuist/openspec/Xcode)一律开 change 分支 → 改 mise.toml/.xcode-version → build-all 全绿再合并
- 两个 Demo app 是活范例,正式项目稳定前不要删
- 推远端:GitHub 私有仓(建仓当天配置;若还没配,现在就去配)
