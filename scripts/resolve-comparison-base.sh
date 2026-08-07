#!/usr/bin/env bash
# resolve-comparison-base.sh — 为 affected verification 解析唯一比较基准。
# 输入:可选显式 ref；否则依据本地 main/feature branch 解析。
# 输出:完整 commit SHA。
# 失败语义:ref 无效、detached 且未显式指定、或找不到 main 基准时非零。
set -uo pipefail

if [ "$#" -gt 1 ]; then
    echo "用法:scripts/resolve-comparison-base.sh [base-ref]" >&2
    exit 2
fi

resolve_commit() {
    ref="$1"
    if ! git rev-parse --verify -q "${ref}^{commit}" >/dev/null; then
        echo "❌ 比较基准 '$ref' 不是可用 commit；CI 请传事件 base SHA，本地请先 fetch main" >&2
        return 1
    fi
    git rev-parse "${ref}^{commit}"
}

if [ "$#" -eq 1 ] && [ -n "$1" ]; then
    resolve_commit "$1"
    exit $?
fi

branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || true)
if [ -z "$branch" ]; then
    echo "❌ detached HEAD 无法推断比较基准；请传 --base <commit>" >&2
    exit 1
fi
if [ "$branch" = main ]; then
    resolve_commit HEAD
    exit $?
fi

for candidate in main origin/main; do
    if git rev-parse --verify -q "${candidate}^{commit}" >/dev/null; then
        if base=$(git merge-base "$candidate" HEAD 2>/dev/null) && [ -n "$base" ]; then
            echo "$base"
            exit 0
        fi
    fi
done

echo "❌ 分支 '$branch' 找不到 main/origin/main 的共同基准；请先 fetch 或传 --base <commit>" >&2
exit 1
