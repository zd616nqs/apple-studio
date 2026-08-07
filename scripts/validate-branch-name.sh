#!/usr/bin/env bash
# validate-branch-name.sh — 校验 change 分支的 scope 与 verb-object 结构。
# 输入:可选分支名；省略时读取当前分支。输出:仅通过退出码表达结果。
# 规则:CHECK-BRANCH-NAME。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
branch="${1:-$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo detached)}"

case "$branch" in
    main | detached) exit 0 ;;
    change/*) ;;
    *) exit 1 ;;
esac

name=${branch#change/}
scope=${name%%-*}
verb_object=${name#"$scope"-}
if ! [[ "$verb_object" =~ ^[a-z0-9]+(-[a-z0-9]+)+$ ]]; then
    exit 1
fi

case "$scope" in
    repo | modules) exit 0 ;;
esac

for app_dir in "$REPO_ROOT"/Apps/*; do
    [ -d "$app_dir" ] || continue
    app_scope=$(basename "$app_dir" | tr '[:upper:]' '[:lower:]')
    [ "$scope" = "$app_scope" ] && exit 0
done

exit 1
