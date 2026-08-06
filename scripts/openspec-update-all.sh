#!/usr/bin/env bash
# OpenSpec 升级后一条命令刷新:根目录工具文件(skills/commands)重生成 + 各 store 健康检查。
# store 清单 = 拥有 openspec/ 目录的路径,自动发现,无需维护。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise。先跑 scripts/bootstrap.sh" >&2
    exit 1
fi

echo "▸ 重生成根目录 OpenSpec 工具文件(claude + codex)"
# init 会顺手在根目录建 openspec/;根目录不是 store(避免抢占"就近发现")——
# 用 trap 保证即使中途失败也清掉,绝不留下根 store
trap 'rm -rf "$REPO_ROOT/openspec"' EXIT
# 用 init --force 幂等重生成(update 依赖根目录有 openspec/,而根目录刻意不设 store)
mise exec -- openspec init --tools claude,codex --force --no-animation . >/dev/null

fail=0
while IFS= read -r store; do
    store_dir=$(dirname "$store")
    echo "▸ store 检查:$store_dir"
    if ! output=$(cd "$store_dir" && mise exec -- openspec status 2>&1); then
        echo "❌ $store_dir 的 openspec status 异常:" >&2
        echo "$output" | head -5 >&2
        fail=1
    fi
done < <(find Apps Modules -maxdepth 2 -type d -name openspec | sort)

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ openspec-update-all 完成"
