#!/usr/bin/env bash
# clone 后一条命令跑通环境。零全局状态:不写任何 home/系统目录的 agent/工具链配置文件
# (mise 自身把工具装进 ~/.local/share/mise,属工具运行时,不在红线范围)。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise(工具链钉版管理)。安装:brew install mise" >&2
    exit 1
fi

echo "▸ mise trust + install(按 mise.toml 钉版安装 Tuist / openspec CLI)"
mise trust --quiet
mise install

echo "▸ 启用版本化 git hooks(.githooks/)"
git config core.hooksPath .githooks

echo "▸ tuist install(解析 Tuist/Package.swift 声明的 SPM 依赖)"
mise exec -- tuist install

echo "▸ tuist generate(生成 workspace)"
mise exec -- tuist generate --no-open

echo "✅ bootstrap 完成。下一步:scripts/build-all.sh"
