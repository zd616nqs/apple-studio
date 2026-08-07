#!/usr/bin/env bash
#
# shared-zone-guard.sh — Claude 专用的共享区改动提醒(PreToolUse 钩子)
#
# 【背景】
# 共享区(Modules/、Tuist/、脚本、规则文件)的改动会影响所有 app。
# AI 助手在专注实现某个功能时,可能顺手就改了共享代码而没意识到影响面。
# 这个钩子在 Claude 每次要编辑/写入共享区文件的那一刻弹出确认,
# 把"你正在动共享区"这件事显式地摆到台面上。
#
# 【为什么它只是辅助】
# 本钩子只对 Claude 生效(Codex 等其他助手不读 .claude/ 配置),
# 所以它只是提前提醒;真正对所有提交者生效的检查在 .githooks/pre-commit。
#
# 【放行规则】
# change/modules-* 分支 = 有意开发共享层,直接放行不打扰;
# 其他分支改共享区 → 弹出确认,由人决定是否继续。
#
set -uo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
rel="${file_path#"$repo_root"/}"

# 只关心共享区路径,其余文件直接放行
case "$rel" in
    Modules/* | Tuist/* | Workspace.swift | scripts/* | .githooks/* | CLAUDE.md | .claude/settings.json) ;;
    *) exit 0 ;;
esac

branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || echo detached)
case "$branch" in
    change/modules-*) exit 0 ;;
esac

# 输出 JSON 必须经 jq 生成:路径/分支名里若含引号或反斜杠,
# 手工拼接会产生非法 JSON,钩子就会静默失效(等于没拦)
jq -cn --arg reason "⚠️ 分支 $branch 上修改共享区 $rel(影响所有 app;红线 3:共享层改动应在 change/modules-* 分支上做)" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
