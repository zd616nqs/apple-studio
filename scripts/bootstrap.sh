#!/usr/bin/env bash
#
# bootstrap.sh — 初始化 fresh clone 的本地开发环境。
# 输入:mise 与仓库 lock。输出:已安装工具、hooksPath、依赖和生成 workspace。
# 失败语义:任一步失败即非零退出；mise/Tuist 可使用其标准用户级缓存。
# 规则:GATE-TOOLCHAIN-VERSION、GATE-AGENT-ENTRY。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise(工具版本管理器)。请先安装:brew install mise" >&2
    exit 1
fi

echo "▸ mise trust + install(按 mise.toml 安装锁定版本的 Tuist / openspec)"
mise trust --quiet
mise install

echo "▸ 启用版本管理的 git 钩子(.githooks/)"
git config core.hooksPath .githooks

echo "▸ tuist install(下载 Tuist/Package.swift 声明的第三方依赖)"
mise exec -- tuist install

echo "▸ tuist generate(生成 Xcode workspace)"
mise exec -- tuist generate --no-open

echo "✅ 环境初始化完成。下一步可运行:scripts/build-all.sh 验证全部 app 能构建"
