#!/usr/bin/env bash
# classify-changes.sh — 将 PR diff 分类为是否需要 Apple runner。
# 输入:base commit 与 head commit。
# 输出:GitHub Actions output 格式的 apple_required=true|false。
# 失败语义:边界无效或 diff 不可读取时非零且不输出决策。
set -uo pipefail

if [ "$#" -ne 2 ]; then
    echo "用法:scripts/ci/classify-changes.sh <base-commit> <head-commit>" >&2
    exit 2
fi

base=$1
head=$2
for boundary in "$base" "$head"; do
    if ! git cat-file -e "${boundary}^{commit}" 2>/dev/null; then
        echo "无效 commit boundary:$boundary" >&2
        exit 1
    fi
done

if ! changed_paths=$(git -c core.quotepath=false diff --name-only "$base" "$head"); then
    echo "无法读取 $base..$head 的 diff" >&2
    exit 1
fi

apple_required=false
while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
        *.md | docs/* | .github/* | .governance/* | .agents/* | .claude/* | \
            Apps/*/openspec/* | Modules/openspec/*)
            ;;
        *)
            apple_required=true
            break
            ;;
    esac
done <<EOF
$changed_paths
EOF

echo "apple_required=$apple_required"
