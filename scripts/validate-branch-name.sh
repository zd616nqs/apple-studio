#!/usr/bin/env bash
# validate-branch-name.sh — 校验 change 分支的 scope 与 verb-object 结构。
# 输入:可选分支名；省略时读取当前分支。--print-scope 输出解析后的合法 scope。
# 规则:CHECK-BRANCH-NAME。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
branch="${1:-$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo detached)}"
print_scope=0
[ "${2:-}" = --print-scope ] && print_scope=1

accept_scope() {
    candidate="$1"
    prefix="change/${candidate}-"
    case "$branch" in
        "$prefix"*) ;;
        *) return 1 ;;
    esac

    verb_object=${branch#"$prefix"}
    if [[ "$verb_object" =~ ^[a-z0-9]+(-[a-z0-9]+)+$ ]]; then
        [ "$print_scope" -eq 0 ] || printf '%s\n' "$candidate"
        exit 0
    fi
    return 1
}

case "$branch" in
    main | detached)
        [ "$print_scope" -eq 0 ] || printf '%s\n' "$branch"
        exit 0
        ;;
    change/*) ;;
    *) exit 1 ;;
esac

accept_scope repo
accept_scope modules

for app_dir in "$REPO_ROOT"/Apps/*; do
    [ -d "$app_dir" ] || continue
    app_scope=$(basename "$app_dir" | tr '[:upper:]' '[:lower:]')
    accept_scope "$app_scope"
done

exit 1
