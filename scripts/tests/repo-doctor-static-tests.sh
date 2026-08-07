#!/usr/bin/env bash
# repo-doctor-static-tests.sh — 在临时 Git fixture 中验证 portable Gate。
# 输入:当前 HEAD 与工作树中的 doctor/pre-commit。输出:逐例 PASS/FAIL。
# 失败语义:任一正例或安全反例不符合预期即非零退出。
# 规则:覆盖 static doctor 及其与 pre-commit 共享的 Gate。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCTOR_SOURCE="$REPO_ROOT/scripts/repo-doctor.sh"
BRANCH_VALIDATOR_SOURCE="$REPO_ROOT/scripts/validate-branch-name.sh"
HOOK_SOURCE="$REPO_ROOT/.githooks/pre-commit"
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

make_fixture() {
    fixture="$TEMP_ROOT/fixture-$1"
    mkdir -p "$fixture"
    git -C "$REPO_ROOT" archive HEAD | tar -x -C "$fixture"
    cp "$DOCTOR_SOURCE" "$fixture/scripts/repo-doctor.sh"
    cp "$BRANCH_VALIDATOR_SOURCE" "$fixture/scripts/validate-branch-name.sh"
    cp "$HOOK_SOURCE" "$fixture/.githooks/pre-commit"
    chmod +x "$fixture/scripts/repo-doctor.sh" "$fixture/scripts/validate-branch-name.sh" \
        "$fixture/.githooks/pre-commit"
    git -C "$fixture" init -q
    git -C "$fixture" config user.name "Synthetic Fixture"
    git -C "$fixture" config user.email "fixture@example.invalid"
    git -C "$fixture" add -A
}

capture_static() {
    set +e
    output=$(cd "$fixture" && REPO_DOCTOR_OPENSPEC="$OPENSPEC_BIN" scripts/repo-doctor.sh --static 2>&1)
    status=$?
    set -e
}

capture_staged() {
    set +e
    output=$(cd "$fixture" && scripts/repo-doctor.sh --staged 2>&1)
    status=$?
    set -e
}

capture_hook() {
    set +e
    output=$(cd "$fixture" && .githooks/pre-commit 2>&1)
    status=$?
    set -e
}

expect_gate() {
    name="$1"
    expected_id="$2"
    mode="$3"
    if [ "$mode" = static ]; then
        capture_static
    else
        capture_staged
    fi
    [ "$status" -ne 0 ] || fail "$name:expected non-zero"
    printf '%s\n' "$output" | grep -q "$expected_id" || fail "$name:missing $expected_id; output=$output"
    pass "$name"
}

expect_shared_gate() {
    name="$1"
    expected_id="$2"
    capture_staged
    [ "$status" -ne 0 ] || fail "$name staged:expected non-zero"
    printf '%s\n' "$output" | grep -q "$expected_id" || fail "$name staged:missing $expected_id; output=$output"
    capture_hook
    [ "$status" -ne 0 ] || fail "$name hook:expected non-zero"
    printf '%s\n' "$output" | grep -q "$expected_id" || fail "$name hook:missing $expected_id; output=$output"
    pass "$name (doctor/hook agree)"
}

make_fixture positive
capture_static
[ "$status" -eq 0 ] || fail "positive static:$output"
capture_hook
[ "$status" -eq 0 ] || fail "positive hook:$output"
printf '%s\n' "$output" | grep -q CHECK-CHANGE-TIER || fail "positive hook:missing advisory tier report"
if command -v xcrun >/dev/null 2>&1 && xcrun --find swift-format >/dev/null 2>&1; then
    printf '%s\n' "$output" | grep -q CHECK-SWIFT-FORMAT || fail "positive hook:missing advisory format report"
fi
pass "positive fixture"

make_fixture matching-app-scope
git -C "$fixture" commit -qm baseline
git -C "$fixture" switch -qc change/demonotes-update-copy
printf '\nmatching scope\n' >> "$fixture/Apps/DemoNotes/CONTEXT.md"
git -C "$fixture" add Apps/DemoNotes/CONTEXT.md
capture_hook
[ "$status" -eq 0 ] || fail "matching App scope changed hook exit:$output"
printf '%s\n' "$output" | grep -q CHECK-BRANCH-NAME && fail "matching App scope reported mismatch:$output"
pass "matching App scope stays clean"

make_fixture mismatched-app-scope
git -C "$fixture" commit -qm baseline
git -C "$fixture" switch -qc change/demonotes-update-copy
printf '\nmismatched scope\n' >> "$fixture/Apps/DemoPhotoMark/CONTEXT.md"
git -C "$fixture" add Apps/DemoPhotoMark/CONTEXT.md
capture_hook
[ "$status" -eq 0 ] || fail "App scope Check changed hook exit:$output"
printf '%s\n' "$output" | grep -q CHECK-BRANCH-NAME || fail "mismatched App scope missing Check:$output"
pass "mismatched App scope reports Check"

make_fixture branch-check
git -C "$fixture" symbolic-ref HEAD refs/heads/topic
capture_static
[ "$status" -eq 0 ] || fail "branch Check changed static exit:$output"
printf '%s\n' "$output" | grep -q CHECK-BRANCH-NAME || fail "branch Check missing report"
pass "branch Check stays advisory"

make_fixture governance-size
i=0
while [ "$i" -lt 300 ]; do
    printf 'advisory governance size fixture line %s\n' "$i" >> "$fixture/GOVERNANCE.md"
    i=$((i + 1))
done
git -C "$fixture" add GOVERNANCE.md
capture_static
[ "$status" -eq 0 ] || fail "governance-size Check changed static exit:$output"
printf '%s\n' "$output" | grep -q CHECK-GOVERNANCE-SIZE || fail "governance-size Check missing report"
pass "governance-size Check stays advisory"

make_fixture root
printf 'synthetic root fixture\n' > "$fixture/UNPLANNED.md"
git -C "$fixture" add UNPLANNED.md
expect_shared_gate "root allowlist" GATE-ROOT-ALLOWLIST staged

make_fixture generated
mkdir -p "$fixture/Apps/DemoNotes/Generated.xcodeproj"
printf 'synthetic generated fixture\n' > "$fixture/Apps/DemoNotes/Generated.xcodeproj/project.pbxproj"
git -C "$fixture" add -f Apps/DemoNotes/Generated.xcodeproj/project.pbxproj
expect_shared_gate "generated artifact" GATE-GENERATED-FILES staged

make_fixture secret
mkdir -p "$fixture/Apps/DemoNotes/Secrets"
printf 'synthetic non-sensitive fixture\n' > "$fixture/Apps/DemoNotes/Secrets/example.txt"
git -C "$fixture" add -f Apps/DemoNotes/Secrets/example.txt
expect_shared_gate "synthetic secret path" GATE-SECRETS staged

make_fixture large
dd if=/dev/zero of="$fixture/Apps/DemoNotes/synthetic-large.bin" bs=1048576 count=6 2>/dev/null
git -C "$fixture" add Apps/DemoNotes/synthetic-large.bin
expect_shared_gate "staged large blob" GATE-LARGE-FILES staged

make_fixture dependency
printf '// synthetic dependency fixture\n' > "$fixture/Apps/DemoNotes/Package.swift"
git -C "$fixture" add Apps/DemoNotes/Package.swift
expect_shared_gate "dependency source" GATE-DEPENDENCY-SOURCE staged

make_fixture agent-link
unlink "$fixture/AGENTS.md"
ln -s /tmp/synthetic-governance "$fixture/AGENTS.md"
git -C "$fixture" add AGENTS.md
expect_gate "absolute Agent link" GATE-AGENT-ENTRY static

make_fixture schema-link
unlink "$fixture/Apps/DemoNotes/openspec/schemas/light-change"
ln -s ../../../../.governance/openspec/schemas/missing "$fixture/Apps/DemoNotes/openspec/schemas/light-change"
git -C "$fixture" add Apps/DemoNotes/openspec/schemas/light-change
expect_gate "dangling schema link" GATE-OPENSPEC-SCHEMA static

make_fixture schema-content
printf 'name: full-change\nversion: invalid\n' > "$fixture/.governance/openspec/schemas/full-change/schema.yaml"
git -C "$fixture" add .governance/openspec/schemas/full-change/schema.yaml
expect_gate "invalid schema content" GATE-OPENSPEC-SCHEMA static

make_fixture toolchain
printf 'not-a-build-id with spaces\n' > "$fixture/.xcode-build-version"
git -C "$fixture" add .xcode-build-version
expect_gate "invalid toolchain lock" GATE-TOOLCHAIN-VERSION static

make_fixture app-structure
git -C "$fixture" rm -q -f Apps/DemoNotes/Resources/PrivacyInfo.xcprivacy
expect_gate "missing App structure" GATE-REQUIRED-VERIFICATION static

make_fixture shell
printf '\nif broken syntax\n' >> "$fixture/scripts/beta-smoke.sh"
git -C "$fixture" add scripts/beta-smoke.sh
expect_gate "invalid shell syntax" GATE-REQUIRED-VERIFICATION static

echo "PASS all $pass_count repo-doctor static fixtures"
