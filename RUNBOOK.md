# RUNBOOK — 三个月不碰之后,十分钟回到工作状态

## 0. 这个仓库是什么

Apple 生态 monorepo:Tuist 负责生成工程,多个 app 共用 Modules/ 共享层,
OpenSpec 管理行为文档,由 AI 助手(Claude Code / Codex)协作开发。
规则的唯一入口:根目录 [CLAUDE.md](CLAUDE.md)。

## 1. 环境重建(换机器 / 重装后)

```bash
brew install mise        # 若还没装(唯一需要手动装的工具)
./scripts/bootstrap.sh   # 安装锁定版本的工具、启用提交检查、拉依赖、生成 workspace
./scripts/build-all.sh   # 全部 app 构建,全部通过 = 环境健康
```

## 2. 日常命令速查

| 要做什么 | 命令 |
|---|---|
| 改了共享层,验证所有 app | `./scripts/build-all.sh` |
| 只测受改动影响的 app | `./scripts/test-affected.sh`(`--list` 只看范围) |
| 工程结构变了(加文件/改依赖) | `mise exec -- tuist generate --no-open` |
| OpenSpec 升级后 | `./scripts/openspec-update-all.sh` |
| 查看某 app 的行为文档/变更 | `(cd Apps/<App> && mise exec -- openspec status)` |

## 3. 开发一个变更(标准流程)

1. 判断级别(根 CLAUDE.md「变更路由」):琐碎改动直接改;行为变更走 `/opsx:propose`
2. 开分支 `change/<app>-<slug>`(共享层用 `change/modules-<slug>`)
3. 测试先行实现:先写测试确认失败,再实现,`./scripts/test-affected.sh` 全部通过
4. 行为变更在**本分支**上执行 `/opsx:archive`(禁 ff;未合并的分支禁 sync)
5. rebase main → `merge --no-ff` → push;**合并后保留 change 分支**(本地和远端都留);
   tag `App-<Name>-x.y.z` **只在真正发版时打**(日常合并不打)

## 4. 常见故障

- **tuist 命令找不到** → 没装 mise 或没运行 bootstrap;所有脚本都通过 `mise exec --`
  调用锁定版本,不要在系统里另装 tuist
- **tuist generate 报声明文件编译错误** → 详细日志在 `~/.local/state/tuist/sessions/…/logs.txt`;
  常见原因:构建设置的值用了 String 变量(见 docs/standards/testing.md 的踩坑清单)
- **混编 app 运行时报 unrecognized selector** → 多半是 `-ObjC` 链接参数丢了
  (工厂已自动处理;绕过工厂手写配置时要自查,见 docs/standards/objc-swift-interop.md)
- **升级 Xcode 后构建异常** → 对照 `.xcode-version` 的锁定版本;beta 版只走
  scripts/beta-smoke.sh 的独立验证通道,不要把日常构建切到 beta
- **提交被 pre-commit 拦下** → 看它打印的红线编号和说明;确认是误报时可用
  `git commit --no-verify` 跳过(应急手段,事后要补救)

## 5. 别忘了

- 工具链升级(Tuist / openspec / Xcode)一律开 change 分支 → 改 mise.toml 或
  .xcode-version → build-all 全部通过再合并;不要顺手升级
- 两个 Demo app 是长期保留的示例工程,正式项目稳定前不要删
- 远端备份:GitHub 私有仓库(已配置 origin;换远端时记得同步推送所有保留的分支)
