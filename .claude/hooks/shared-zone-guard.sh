#!/usr/bin/env bash
# Claude 侧副防线(PreToolUse Edit|Write):分支感知的共享区确认。
# change/modules-* 分支 = 有意开发共享层,直接放行;其余分支弹确认,防 agent 静默影响所有 app。
# 主防线在 .githooks/pre-commit(工具中立;本 hook 对 Codex 无效,只是 Claude 的提前预警)。
set -uo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
rel="${file_path#"$repo_root"/}"

case "$rel" in
    Modules/* | Tuist/* | Workspace.swift | scripts/* | .githooks/* | CLAUDE.md | .claude/settings.json) ;;
    *) exit 0 ;;
esac

branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || echo detached)
case "$branch" in
    change/modules-*) exit 0 ;;
esac

# 经 jq 生成 JSON:路径/分支名里的引号反斜杠都安全转义,坏 JSON 会让 hook 静默失效
jq -cn --arg reason "⚠️ 分支 $branch 上修改共享区 $rel(影响所有 app;红线 3:共享层改动走 change/modules-* 分支)" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
