#!/usr/bin/env bash
# local-governance-tests.sh — 验证 macOS doctor 分支、commit-msg 与 Claude deny。
# 输入:当前 HEAD、工作树 hooks/doctor 和本机锁定工具链。输出:逐例 PASS/FAIL。
# 失败语义:任一 Gate/Check 分层或本机/CI 模式不符合预期即非零退出。
# 规则:GATE-DIRECT-MAIN、GATE-TOOLCHAIN-VERSION、GATE-AGENT-ENTRY、
# CHECK-COMMIT-FORMAT、CHECK-BREAK-GLASS-REASON。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
HOOK_SOURCE="$REPO_ROOT/.githooks/commit-msg"
DOCTOR_SOURCE="$REPO_ROOT/scripts/repo-doctor.sh"
OPENSPEC_BIN="$(cd "$REPO_ROOT" && mise which openspec)"
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
pass_count=0

pass() {
    pass_count=$((pass_count + 1))
    echo "PASS $1"
}

fail() {
    echo "FAIL $1" >&2
    exit 1
}

capture_commit_hook() {
    set +e
    output=$(cd "$commit_fixture" && .githooks/commit-msg "$message_file" 2>&1)
    status=$?
    set -e
}

commit_fixture="$TEMP_ROOT/commit-hook"
mkdir -p "$commit_fixture/.githooks"
git -C "$commit_fixture" init -q
cp "$HOOK_SOURCE" "$commit_fixture/.githooks/commit-msg"
chmod +x "$commit_fixture/.githooks/commit-msg"
message_file="$commit_fixture/message.txt"

git -C "$commit_fixture" symbolic-ref HEAD refs/heads/main
printf 'feat(repo): 普通 main 提交\n' > "$message_file"
capture_commit_hook
[ "$status" -ne 0 ] || fail "normal main commit should fail"
printf '%s\n' "$output" | grep -q GATE-DIRECT-MAIN || fail "normal main commit missing Gate ID"
pass "normal main commit rejected"

printf 'feat(repo): 应急修复\n\nBreak-Glass: 恢复无法等待的仓库入口\n' > "$message_file"
capture_commit_hook
[ "$status" -eq 0 ] || fail "main break-glass should pass:$output"
pass "non-empty main break-glass accepted"

git -C "$commit_fixture" symbolic-ref HEAD refs/heads/change/repo-local-health
printf 'not conventional\n' > "$message_file"
capture_commit_hook
[ "$status" -eq 0 ] || fail "commit format Check changed exit:$output"
printf '%s\n' "$output" | grep -q CHECK-COMMIT-FORMAT || fail "commit format Check missing"
pass "commit format stays advisory"

printf 'feat(repo): 空应急原因\n\nBreak-Glass:   \n' > "$message_file"
capture_commit_hook
[ "$status" -eq 0 ] || fail "empty non-main trailer Check changed exit:$output"
printf '%s\n' "$output" | grep -q CHECK-BREAK-GLASS-REASON || fail "empty trailer Check missing"
pass "non-main break-glass reason stays advisory"

for deny_rule in \
    'Read(./Secrets/**)' 'Read(./**/Secrets/**)' 'Read(./**/*.secrets.*)' \
    'Edit(./Secrets/**)' 'Edit(./**/Secrets/**)' 'Edit(./**/*.secrets.*)' \
    'Write(./Secrets/**)' 'Write(./**/Secrets/**)' 'Write(./**/*.secrets.*)'; do
    jq -e --arg rule "$deny_rule" '.permissions.deny | index($rule) != null' \
        "$REPO_ROOT/.claude/settings.json" >/dev/null || fail "Claude deny missing:$deny_rule"
done
pass "Claude synthetic Secret path deny retained"

fixture="$TEMP_ROOT/doctor"
mkdir -p "$fixture"
git -C "$REPO_ROOT" archive HEAD | tar -x -C "$fixture"
cp "$DOCTOR_SOURCE" "$fixture/scripts/repo-doctor.sh"
cp "$HOOK_SOURCE" "$fixture/.githooks/commit-msg"
chmod +x "$fixture/scripts/repo-doctor.sh" "$fixture/.githooks/commit-msg"
git -C "$fixture" init -q
git -C "$fixture" add -A
git -C "$fixture" config core.hooksPath .wrong-hooks

set +e
output=$(cd "$fixture" && REPO_DOCTOR_OPENSPEC="$OPENSPEC_BIN" scripts/repo-doctor.sh 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] || fail "local doctor should reject wrong hooksPath"
printf '%s\n' "$output" | grep -q 'GATE-AGENT-ENTRY:core.hooksPath' || fail "local hooksPath Gate missing"
pass "local doctor rejects missing hooksPath"

set +e
output=$(cd "$fixture" && REPO_DOCTOR_OPENSPEC="$OPENSPEC_BIN" scripts/repo-doctor.sh --ci 2>&1)
status=$?
set -e
printf '%s\n' "$output" | grep -q 'core.hooksPath' && fail "CI doctor inspected developer hooksPath"
pass "CI doctor ignores developer hooksPath"

printf 'SYNTHETIC123\n' > "$fixture/.xcode-build-version"
git -C "$fixture" add .xcode-build-version
set +e
output=$(cd "$fixture" && REPO_DOCTOR_OPENSPEC="$OPENSPEC_BIN" scripts/repo-doctor.sh --ci 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] || fail "CI doctor should reject exact Xcode build mismatch"
printf '%s\n' "$output" | grep -q 'GATE-TOOLCHAIN-VERSION:Xcode build' || fail "exact Xcode build Gate missing"
pass "exact Xcode build mismatch rejected"

echo "PASS all $pass_count local governance fixtures"
