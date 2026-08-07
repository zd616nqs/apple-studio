#!/usr/bin/env bash
#
# openspec-update-all.sh — 刷新 OpenSpec Agent 适配并重验产品 stores。
# 输入:锁定 OpenSpec 版本、canonical schemas、现有个人 skill 链接。
# 输出:更新的 commands/skills；临时 root store 在退出时删除。
# 失败语义:个人链接漂移、schema/store 验证失败时非零退出。
# 规则:GATE-AGENT-ENTRY、GATE-OPENSPEC-SCHEMA。
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
