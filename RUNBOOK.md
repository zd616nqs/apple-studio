# apple-studio 运行手册

本文件只保存命令与故障恢复。规则、等级和适用范围以 `GOVERNANCE.md` 为准。

## 环境重建

```bash
brew install mise
scripts/bootstrap.sh
scripts/repo-doctor.sh
scripts/build-all.sh
```

`bootstrap.sh` 安装 `mise.toml` 中的工具、启用仓库 hook、安装 Tuist 依赖并生成 `AppleStudio.xcworkspace`。workspace 是生成物；每次可由 manifest 重建。

## 命令速查

| 目的 | 命令 |
| --- | --- |
| 仓库完整体检（本机） | `scripts/repo-doctor.sh` |
| portable 静态体检 | `scripts/repo-doctor.sh --static` |
| macOS CI 体检 | `scripts/repo-doctor.sh --ci` |
| 生成并构建全部 App | `scripts/build-all.sh` |
| 查看受影响 App | `scripts/test-affected.sh --list` |
| 测试受影响 App | `scripts/test-affected.sh` |
| 指定影响面基准 | `scripts/test-affected.sh --base <ref>` |
| 重新生成 workspace | `mise exec -- tuist generate --no-open` |
| OpenSpec 更新后刷新适配 | `scripts/openspec-update-all.sh` |
| 验证某 store | `(cd Apps/<App> && mise exec -- openspec validate --all --strict --no-interactive)` |
| beta Xcode 非阻塞冒烟 | `scripts/beta-smoke.sh [Xcode-beta.app]` |

## Break-glass

本地 hook 误报且工作不能等待时，在提交正文留下具体原因：

```text
Break-Glass: <为什么必须绕过、后续如何补验证>
```

需要跳过本地 hook 时：

```bash
git commit --no-verify -m "<conventional commit>" -m "Break-Glass: <具体原因>"
```

`--no-verify` 会跳过本地 hook，所以可审计性来自提交 trailer。它不会改变远端 CI 结论；补跑命令由 `GATE-REQUIRED-VERIFICATION` 决定。

## 常见故障

- `mise` 不存在：先执行 `brew install mise`，再运行 `scripts/bootstrap.sh`。
- Tuist session 报权限或 manifest 编译错误：终端输出会给出 session 日志路径；先检查 `mise exec -- tuist version`，再检查对应 manifest。
- workspace 或 project 状态异常：关闭 Xcode，删除 ignored 生成物，再运行 `mise exec -- tuist generate --no-open`。不要删除 manifest 或 `Tuist/Package.resolved`。
- 依赖没有安装：运行 `mise exec -- tuist install` 后重新 generate。
- 找不到可用 Simulator：运行 `xcrun simctl list devices available`，确认已安装与 Xcode 匹配的 runtime。
- 测试宿主启动即崩溃：混编 App 先检查 `OTHER_LDFLAGS` 是否仍有 `-ObjC`，再读 `docs/standards/objc-swift-interop.md`。
- OpenSpec 找错 store：切换到 `Apps/<App>` 或 `Modules` 再执行命令；仓库根不建立 `openspec/`。
- OpenSpec update 失败：确认没有 root `openspec/` 残留，运行 `scripts/openspec-update-all.sh`，再按输出修复 schema 或链接。
- hook 未执行：运行 `git config core.hooksPath .githooks`；doctor 会报告当前值。

## OpenSpec 退出

退出是一次性迁移，不维持双目录：

1. 先确认 `tuist generate`、`build-all.sh` 与 `test-affected.sh` 在不调用 OpenSpec 的情况下通过。
2. 将 `Apps/<App>/openspec/specs` 移到 `Apps/<App>/Specs`，将 `Modules/openspec/specs` 移到 `Modules/Specs`。
3. 决定归档 change 的保留范围；它们是审计历史，不是产品运行依赖。
4. 删除 OpenSpec 的 mise 依赖、`.governance/openspec/`、store config/schema 适配和生成的 Agent commands/skills。
5. 更新 `GOVERNANCE.md` 路由、doctor/CI 与本文命令，再运行完整 build/test。

产品 Swift、Objective-C、Tuist manifest 和测试接口不因退出而改变。真正退出前不创建中立 `Specs/` 副本。

## 接入个人 skill

只在有真实用例时创建，名称使用 kebab-case；`openspec-` 为保留前缀。先检查目标名没有占用：

```bash
test ! -e .tooling/skills/<name>
test ! -e .claude/skills/<name>
mkdir -p .tooling/skills/<name>
ln -s ../../.tooling/skills/<name> .claude/skills/<name>
```

唯一源码放在 `.tooling/skills/<name>/SKILL.md`。Claude 通过上面的相对链接读取，Codex 通过已有 `.agents/skills -> ../.claude/skills` 读取同一目录。Skill description 只写触发条件；工程规则用链接指向 `.swift-format` 或 `docs/standards/`，不复制正文。

完成后检查：

```bash
readlink .claude/skills/<name>
realpath .claude/skills/<name>
scripts/repo-doctor.sh --static
```

OpenSpec 升级后运行 `scripts/openspec-update-all.sh`；它会在更新前后核对个人 skill 链接。
