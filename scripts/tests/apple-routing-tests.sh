#!/usr/bin/env bash
# apple-routing-tests.sh — 验证 Apple CI 路由、比较基准与 Simulator 选择。
# 输入:无；在临时 fixture 中构造代表性 Git diff 与 simctl JSON。
# 输出:逐例 PASS/FAIL 及汇总。
# 失败语义:任一路由或确定性边界不符合预期即非零。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CLASSIFIER="$REPO_ROOT/scripts/ci/classify-changes.sh"
BASE_RESOLVER="$REPO_ROOT/scripts/resolve-comparison-base.sh"
SIMULATOR_SELECTOR="$REPO_ROOT/scripts/select-ios-simulator.sh"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
FULL_WORKFLOW="$REPO_ROOT/.github/workflows/full-regression.yml"
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

expect_route() {
    name="$1"
    path="$2"
    expected_required="$3"
    expected_scope="$4"
    mkdir -p "$FIXTURE/$(dirname "$path")"
    printf 'change-%s\n' "$name" >> "$FIXTURE/$path"
    git -C "$FIXTURE" add .
    git -C "$FIXTURE" commit -qm "$name"
    head=$(git -C "$FIXTURE" rev-parse HEAD)
    if output=$(cd "$FIXTURE" && "$CLASSIFIER" "$previous" "$head" 2>&1); then
        actual_required=$(printf '%s\n' "$output" | sed -n 's/^apple_required=//p')
        actual_scope=$(printf '%s\n' "$output" | sed -n 's/^verification_scope=//p')
    else
        actual_required=error
        actual_scope=error
    fi
    if [ "$actual_required:$actual_scope" = "$expected_required:$expected_scope" ]; then
        pass "$name"
    else
        fail "${name}（期望 ${expected_required}:${expected_scope}，实际 ${actual_required}:${actual_scope}）"
    fi
    previous=$head
}

git -C "$FIXTURE" init -q -b main
git -C "$FIXTURE" config user.name fixture
git -C "$FIXTURE" config user.email fixture@example.invalid
printf 'baseline\n' > "$FIXTURE/README.md"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm baseline
previous=$(git -C "$FIXTURE" rev-parse HEAD)

expect_route "documentation routes none" docs/onboarding.md false none
expect_route "single App routes affected" Apps/Demo/Sources/App.swift true affected
expect_route "shared Module routes all" Modules/Studio/Sources/Studio.swift true all
expect_route "root Tuist config routes all" Tuist.swift true all
expect_route "toolchain lock routes all" mise.toml true all
expect_route "governance schema routes none" .governance/openspec/schemas/full-change/schema.yaml false none
expect_route "build script routes all" scripts/build-all.sh true all

git -C "$FIXTURE" switch -q main
main_head=$(git -C "$FIXTURE" rev-parse HEAD)
git -C "$FIXTURE" switch -qc change/demo-work
printf 'branch\n' >> "$FIXTURE/README.md"
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm branch
expected_base=$(git -C "$FIXTURE" merge-base main HEAD)
if actual_base=$(cd "$FIXTURE" && "$BASE_RESOLVER" 2>/dev/null) && [ "$actual_base" = "$expected_base" ]; then
    pass "feature branch resolves merge-base"
else
    fail "feature branch resolves merge-base"
fi
if actual_base=$(cd "$FIXTURE" && "$BASE_RESOLVER" "$main_head" 2>/dev/null) && [ "$actual_base" = "$main_head" ]; then
    pass "explicit base resolves exact commit"
else
    fail "explicit base resolves exact commit"
fi
git -C "$FIXTURE" switch -q main
if actual_base=$(cd "$FIXTURE" && "$BASE_RESOLVER" 2>/dev/null) && [ "$actual_base" = "$main_head" ]; then
    pass "main branch resolves HEAD"
else
    fail "main branch resolves HEAD"
fi
git -C "$FIXTURE" switch -q --detach
if (cd "$FIXTURE" && "$BASE_RESOLVER" >/dev/null 2>&1); then
    fail "detached local mode requires explicit base"
else
    pass "detached local mode requires explicit base"
fi

cat > "$FIXTURE/simulators.json" <<'JSON'
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
      {"name": "iPhone 17", "udid": "OLD-UDID", "isAvailable": true}
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
      {"name": "iPhone 17", "udid": "B-UDID", "isAvailable": true},
      {"name": "iPhone 17", "udid": "A-UDID", "isAvailable": true},
      {"name": "iPad Pro", "udid": "IPAD-UDID", "isAvailable": true}
    ]
  }
}
JSON
if udid=$("$SIMULATOR_SELECTOR" "$FIXTURE/simulators.json" 2>/dev/null) && [ "$udid" = A-UDID ]; then
    pass "latest iOS duplicate names resolve deterministic UDID"
else
    fail "latest iOS duplicate names resolve deterministic UDID"
fi
printf '{"devices":{}}\n' > "$FIXTURE/no-simulators.json"
if "$SIMULATOR_SELECTOR" "$FIXTURE/no-simulators.json" >/dev/null 2>&1; then
    fail "missing iPhone simulator fails"
else
    pass "missing iPhone simulator fails"
fi

if grep -Eq '^  push:' "$CI_WORKFLOW" && grep -q 'runs-on: xcode-27' "$CI_WORKFLOW" && \
    grep -q 'mise exec -- tuist install' "$CI_WORKFLOW"; then
    pass "PR workflow includes push and exact Xcode runner"
else
    fail "PR workflow includes push and exact Xcode runner"
fi
if [ -f "$FULL_WORKFLOW" ] && grep -Eq '^  schedule:' "$FULL_WORKFLOW" && \
    grep -Eq '^  workflow_dispatch:' "$FULL_WORKFLOW" && \
    grep -q 'runs-on: xcode-27' "$FULL_WORKFLOW" && \
    grep -q 'mise exec -- tuist install' "$FULL_WORKFLOW" && \
    grep -q 'scripts/build-all.sh' "$FULL_WORKFLOW" && \
    grep -q 'scripts/test-affected.sh --all' "$FULL_WORKFLOW"; then
    pass "full regression supports schedule and manual dispatch"
else
    fail "full regression supports schedule and manual dispatch"
fi
if ruby -e 'require "yaml"; ARGV.each { |path| YAML.parse_file(path) }' \
    "$CI_WORKFLOW" "$FULL_WORKFLOW" >/dev/null 2>&1; then
    pass "Apple workflows are valid YAML"
else
    fail "Apple workflows are valid YAML"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL:apple routing tests:$failures failure(s), $passes pass(es)" >&2
    exit 1
fi
echo "PASS:apple routing tests:$passes cases"
