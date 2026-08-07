#!/usr/bin/env bash
# ci-gate-tests.sh — 验证 PR 分类与最终 gate 的失败关闭语义。
# 输入:无；在临时 Git fixture 中构造代表性 diff。
# 输出:逐例 PASS/FAIL 及汇总。
# 失败语义:任一分类或状态矩阵不符合预期即非零。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CLASSIFIER="$REPO_ROOT/scripts/ci/classify-changes.sh"
EVALUATOR="$REPO_ROOT/scripts/ci/evaluate-gate.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

passes=0
failures=0

pass() {
    echo "PASS:$1"
    passes=$((passes + 1))
}

fail() {
    echo "FAIL:$1" >&2
    failures=$((failures + 1))
}

expect_gate() {
    name="$1"
    expected="$2"
    shift 2
    if "$EVALUATOR" "$@" >/dev/null 2>&1; then
        actual=success
    else
        actual=failure
    fi
    if [ "$actual" = "$expected" ]; then
        pass "$name"
    else
        fail "${name}（期望 ${expected}，实际 ${actual}）"
    fi
}

expect_classification() {
    name="$1"
    expected="$2"
    base="$3"
    head="$4"
    if output=$(cd "$FIXTURE" && "$CLASSIFIER" "$base" "$head" 2>&1); then
        actual=$(printf '%s\n' "$output" | sed -n 's/^apple_required=//p')
    else
        actual=error
    fi
    if [ "$actual" = "$expected" ]; then
        pass "$name"
    else
        fail "${name}（期望 ${expected}，实际 ${actual}；输出:${output}）"
    fi
}

expect_workflow_text() {
    name="$1"
    pattern="$2"
    if grep -Eq "$pattern" "$WORKFLOW"; then
        pass "$name"
    else
        fail "$name"
    fi
}

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name fixture
git -C "$FIXTURE" config user.email fixture@example.invalid
mkdir -p "$FIXTURE/docs" "$FIXTURE/Apps/Demo/Sources"
printf 'baseline\n' > "$FIXTURE/docs/onboarding.md"
printf 'baseline\n' > "$FIXTURE/Apps/Demo/Sources/App.swift"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm baseline
base=$(git -C "$FIXTURE" rev-parse HEAD)

printf 'documentation\n' >> "$FIXTURE/docs/onboarding.md"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm docs
docs_head=$(git -C "$FIXTURE" rev-parse HEAD)
expect_classification "documentation diff skips Apple" false "$base" "$docs_head"

printf 'source\n' >> "$FIXTURE/Apps/Demo/Sources/App.swift"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm source
source_head=$(git -C "$FIXTURE" rev-parse HEAD)
expect_classification "Apple source diff requires Apple" true "$docs_head" "$source_head"

if (cd "$FIXTURE" && "$CLASSIFIER" not-a-sha "$source_head" >/dev/null 2>&1); then
    fail "invalid diff boundary fails classification"
else
    pass "invalid diff boundary fails classification"
fi

expect_gate "explicit false accepts skipped Apple" success success false success skipped
expect_gate "explicit true accepts successful Apple" success success true success success
expect_gate "classification failure is rejected" failure failure false success skipped
expect_gate "missing classification is rejected" failure success "" success skipped
expect_gate "invalid classification is rejected" failure success maybe success skipped
expect_gate "static failure is rejected" failure success false failure skipped
expect_gate "true plus skipped Apple is rejected" failure success true success skipped
expect_gate "false plus successful Apple is inconsistent" failure success false success success
expect_gate "cancelled Apple is rejected" failure success true success cancelled

if ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0))' "$WORKFLOW" >/dev/null 2>&1; then
    pass "workflow is valid YAML"
else
    fail "workflow is valid YAML"
fi
expect_workflow_text "workflow triggers on pull requests" '^  pull_request:'
expect_workflow_text "workflow exposes stable gate job" '^  gate:'
expect_workflow_text "gate uses always condition" '^    if: \$\{\{ always\(\) \}\}$'
expect_workflow_text "static job runs portable doctor" 'scripts/repo-doctor\.sh --static'
if grep -Eq '^  (schedule|workflow_dispatch):' "$WORKFLOW"; then
    fail "PR workflow does not claim scheduled regression"
else
    pass "PR workflow does not claim scheduled regression"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL:ci gate tests:$failures failure(s), $passes pass(es)" >&2
    exit 1
fi
echo "PASS:ci gate tests:$passes cases"
