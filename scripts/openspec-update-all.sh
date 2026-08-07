#!/usr/bin/env bash
#
# openspec-update-all.sh — OpenSpec 升级后,一条命令刷新它生成的所有文件
#
# 【背景】
# OpenSpec 会在仓库根生成一批"驾驶手册"文件(.claude/skills/openspec-* 和
# .claude/commands/opsx/*),教 AI 助手怎么正确使用 openspec 命令行。
# 这些文件是特定版本的 OpenSpec 生成的:升级 OpenSpec 后如果不重新生成,
# 手册和命令行的行为就会对不上。
#
# 【为什么用 init --force 而不是 update】
# openspec update 要求当前目录已经有 openspec/ 目录才肯工作,
# 而本仓库的根目录刻意不放 openspec/(见下),所以用幂等的 init --force 代替。
#
# 【为什么根目录不能有 openspec/ 目录】
# openspec 命令按"从当前目录向上找最近的 openspec/"来定位工作区。
# 每个 app 和共享层各有自己的 openspec/(行为文档跟着代码走);
# 根目录若也有一个,就会抢走定位,导致变更文档写错地方。
# init 过程会顺手在根目录建一个,所以脚本必须把它删掉——
# 用 trap 保证即使中途出错也一定会删。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise。请先运行 scripts/bootstrap.sh" >&2
    exit 1
fi

snapshot_personal_links() {
    find .claude/skills -mindepth 1 -maxdepth 1 -type l ! -name 'openspec-*' -print0 |
        sort -z |
        while IFS= read -r -d '' link; do
            printf '%s\t%s\n' "$link" "$(readlink "$link")"
        done
}

temp_dir=$(mktemp -d)
before_links="$temp_dir/personal-links.before"
after_links="$temp_dir/personal-links.after"
snapshot_personal_links > "$before_links"

echo "▸ 重新生成根目录的 OpenSpec 工具文件(Claude + Codex 两套)"
trap 'rm -rf "$REPO_ROOT/openspec" "$temp_dir"' EXIT
mise exec -- openspec init --tools claude,codex --force --no-animation . >/dev/null

snapshot_personal_links > "$after_links"
if ! cmp -s "$before_links" "$after_links"; then
    echo "❌ GATE-AGENT-ENTRY:OpenSpec update 改动了个人 skill 软链" >&2
    diff -u "$before_links" "$after_links" >&2 || true
    exit 1
fi
if [ "$(readlink .agents/skills 2>/dev/null || true)" != "../.claude/skills" ]; then
    echo "❌ GATE-AGENT-ENTRY:.agents/skills 入口缺失或目标错误" >&2
    exit 1
fi

# 逐个检查每个 openspec 工作区是否仍然健康(升级偶尔会改文件格式)
fail=0
while IFS= read -r store; do
    store_dir=$(dirname "$store")
    echo "▸ 检查:$store_dir"
    for schema in light-change full-change; do
        if ! output=$(cd "$store_dir" && mise exec -- openspec schema validate "$schema" --json 2>&1); then
            echo "❌ GATE-OPENSPEC-SCHEMA:$store_dir/$schema 无效:" >&2
            echo "$output" | head -10 >&2
            fail=1
        fi
    done
    if ! output=$(cd "$store_dir" && mise exec -- openspec validate --all --strict --no-interactive --json 2>&1); then
        echo "❌ GATE-OPENSPEC-SCHEMA:$store_dir 的内容验证失败:" >&2
        echo "$output" | head -10 >&2
        fail=1
    fi
done < <(find Apps Modules -maxdepth 2 -type d -name openspec | sort)

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ openspec-update-all 完成"
