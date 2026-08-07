#!/usr/bin/env bash
# repo-doctor.sh — 统一验证仓库内容、适配链接与本机工具链健康。
# 输入:默认本地完整模式；--static portable 内容模式；--ci 跳过 hooksPath；
#      --staged 是 pre-commit 使用的内部快速模式。
# 输出:带稳定规则 ID 的 Gate/Check 诊断与汇总。
# 失败语义:任一 Gate 失败即非零；Check 只报告。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

MODE=local
case "${1:-}" in
    "") ;;
    --static) MODE=static ;;
    --ci) MODE=ci ;;
    --staged) MODE=staged ;;
    *)
        echo "用法:scripts/repo-doctor.sh [--static|--ci]" >&2
        exit 2
        ;;
esac

MAX_BLOB_SIZE=$((5 * 1024 * 1024))
gate_failures=0
check_count=0

gate_fail() {
    rule_id="$1"
    shift
    echo "❌ $rule_id:$*" >&2
    gate_failures=$((gate_failures + 1))
}

check_report() {
    rule_id="$1"
    shift
    echo "⚠️  $rule_id:$*" >&2
    check_count=$((check_count + 1))
}

is_allowed_root_entry() {
    case "$1" in
        .agents | .claude | .github | .githooks | .governance | .tooling | \
            Apps | Modules | Tuist | docs | scripts | \
            .gitignore | .swift-format | .xcode-version | .xcode-build-version | \
            AGENTS.md | CLAUDE.md | GOVERNANCE.md | CONTEXT.md | RUNBOOK.md | \
            Workspace.swift | Tuist.swift | mise.toml) return 0 ;;
        *) return 1 ;;
    esac
}

is_generated_path() {
    case "$1" in
        .DS_Store | */.DS_Store | \
            *.xcodeproj | *.xcodeproj/* | */*.xcodeproj | */*.xcodeproj/* | \
            *.xcworkspace | *.xcworkspace/* | */*.xcworkspace | */*.xcworkspace/* | \
            Derived | Derived/* | */Derived | */Derived/* | \
            DerivedData | DerivedData/* | */DerivedData | */DerivedData/* | \
            .build | .build/* | */.build | */.build/* | \
            xcuserdata | xcuserdata/* | */xcuserdata | */xcuserdata/* | \
            *.xcuserstate | */*.xcuserstate) return 0 ;;
        *) return 1 ;;
    esac
}

is_secret_path() {
    lower_path=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$lower_path" in
        secrets | secrets/* | */secrets | */secrets/* | \
            secret | secret/* | */secret | */secret/* | \
            *.secrets.* | */*.secrets.* | \
            .env | .env.* | */.env | */.env.* | \
            *.p12 | */*.p12 | *.mobileprovision | */*.mobileprovision | \
            authkey_*.p8 | */authkey_*.p8) return 0 ;;
        *) return 1 ;;
    esac
}

is_dependency_source_violation() {
    path="$1"
    case "$path" in
        Tuist/Package.swift | Tuist/Package.resolved) return 1 ;;
        Package.swift | Package.resolved | */Package.swift | */Package.resolved | \
            Podfile | */Podfile | Podfile.lock | */Podfile.lock | \
            Cartfile | */Cartfile | Cartfile.resolved | */Cartfile.resolved | \
            Mintfile | */Mintfile | *.podspec | */*.podspec) return 0 ;;
        *) return 1 ;;
    esac
}

paths_for_mode() {
    if [ "$MODE" = staged ]; then
        git -c core.quotepath=false diff --cached --name-only --diff-filter=ACMR
    else
        git -c core.quotepath=false ls-files
    fi
}

check_content_gates() {
    paths=$(paths_for_mode)
    [ -n "$paths" ] || return 0

    while IFS= read -r path; do
        [ -n "$path" ] || continue
        root_entry=${path%%/*}
        if ! is_allowed_root_entry "$root_entry"; then
            gate_fail GATE-ROOT-ALLOWLIST "$path 的根 entry '$root_entry' 不在 GOVERNANCE 清单"
        fi

        if is_generated_path "$path"; then
            gate_fail GATE-GENERATED-FILES "$path 是不可入库的生成物"
        fi

        if is_secret_path "$path"; then
            gate_fail GATE-SECRETS "$path 命中 Secret/本地凭据路径模式"
        fi

        if is_dependency_source_violation "$path"; then
            gate_fail GATE-DEPENDENCY-SOURCE "$path 在 Tuist/Package.swift 之外声明依赖图"
        fi

        size=$(git cat-file -s ":$path" 2>/dev/null || echo 0)
        case "$size" in
            '' | *[!0-9]*) size=0 ;;
        esac
        if [ "$size" -gt "$MAX_BLOB_SIZE" ]; then
            gate_fail GATE-LARGE-FILES "$path 的 index blob 为 $size bytes（上限 ${MAX_BLOB_SIZE}）"
        fi
    done <<EOF
$paths
EOF
}

check_link() {
    rule_id="$1"
    link="$2"
    expected_target="$3"
    allowed_root="$4"

    if [ ! -L "$link" ]; then
        gate_fail "$rule_id" "$link 不是软链"
        return
    fi
    target=$(readlink "$link")
    case "$target" in
        /*)
            gate_fail "$rule_id" "$link 使用绝对目标 $target"
            return
            ;;
    esac
    if [ -n "$expected_target" ] && [ "$target" != "$expected_target" ]; then
        gate_fail "$rule_id" "$link 目标为 ${target}，预期 $expected_target"
    fi
    resolved=$(realpath "$link" 2>/dev/null || true)
    if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
        gate_fail "$rule_id" "$link -> $target 已断开"
        return
    fi
    allowed_resolved=$(realpath "$allowed_root" 2>/dev/null || true)
    if [ -z "$allowed_resolved" ]; then
        gate_fail "$rule_id" "允许边界 $allowed_root 不存在"
        return
    fi
    case "$resolved" in
        "$allowed_resolved" | "$allowed_resolved"/*) ;;
        *) gate_fail "$rule_id" "$link 解析到允许边界外:$resolved" ;;
    esac
}

run_openspec() {
    if [ -n "${REPO_DOCTOR_OPENSPEC:-}" ]; then
        "$REPO_DOCTOR_OPENSPEC" "$@"
    elif command -v mise >/dev/null 2>&1; then
        mise exec -- openspec "$@"
    elif command -v openspec >/dev/null 2>&1; then
        openspec "$@"
    else
        return 127
    fi
}

check_agent_links() {
    check_link GATE-AGENT-ENTRY AGENTS.md GOVERNANCE.md "$REPO_ROOT/GOVERNANCE.md"
    check_link GATE-AGENT-ENTRY CLAUDE.md GOVERNANCE.md "$REPO_ROOT/GOVERNANCE.md"
    check_link GATE-AGENT-ENTRY .agents/skills ../.claude/skills "$REPO_ROOT/.claude/skills"

    symlinks=$(git ls-files -s | awk '$1 == "120000" { sub(/^[^\t]*\t/, ""); print }')
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        if [ ! -L "$link" ]; then
            gate_fail GATE-AGENT-ENTRY "$link 在 index 中是软链但工作树类型不匹配"
            continue
        fi
        target=$(readlink "$link")
        case "$target" in
            /*) gate_fail GATE-AGENT-ENTRY "$link 使用绝对目标 $target" ;;
        esac
        resolved=$(realpath "$link" 2>/dev/null || true)
        case "$resolved" in
            "$REPO_ROOT"/*) ;;
            *) gate_fail GATE-AGENT-ENTRY "$link 已断开或解析到仓库外:$target" ;;
        esac
    done <<EOF
$symlinks
EOF

    for link in .claude/skills/*; do
        [ -L "$link" ] || continue
        case "$(basename "$link")" in
            openspec-*) continue ;;
        esac
        check_link GATE-AGENT-ENTRY "$link" "" "$REPO_ROOT/.tooling/skills"
    done
}

check_openspec() {
    schema_names=$(find .governance/openspec/schemas -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
        sed 's#^.*/##' | sort)
    expected_schema_names=$(printf 'full-change\nlight-change')
    if [ "$schema_names" != "$expected_schema_names" ]; then
        gate_fail GATE-OPENSPEC-SCHEMA "custom schema 必须且只能是 full-change/light-change；实际:$(printf '%s' "$schema_names" | tr '\n' ' ')"
    fi

    stores="Modules"
    for app_dir in Apps/*; do
        [ -d "$app_dir" ] || continue
        app_name=$(basename "$app_dir")
        stores="$stores
Apps/$app_name"

        for required in CONTEXT.md Project.swift Resources/PrivacyInfo.xcprivacy Sources Tests openspec/config.yaml; do
            if [ ! -e "$app_dir/$required" ]; then
                gate_fail GATE-REQUIRED-VERIFICATION "$app_dir 缺少 ${required}，无法执行标准 App 验证"
            fi
        done
    done

    for required in Modules/Project.swift Modules/openspec/config.yaml; do
        if [ ! -e "$required" ]; then
            gate_fail GATE-REQUIRED-VERIFICATION "缺少 $required"
        fi
    done

    while IFS= read -r store; do
        [ -n "$store" ] || continue
        config="$store/openspec/config.yaml"
        if [ ! -f "$config" ]; then
            gate_fail GATE-OPENSPEC-SCHEMA "$store 缺少 openspec/config.yaml"
            continue
        fi
        if ! grep -Eq '^schema:[[:space:]]+full-change[[:space:]]*$' "$config"; then
            gate_fail GATE-OPENSPEC-SCHEMA "$config 未默认 full-change"
        fi
        if grep -Eq '^rules:' "$config"; then
            gate_fail GATE-OPENSPEC-SCHEMA "$config 仍含共享 rules 正文"
        fi
        for rule_id in GATE-REQUIRED-VERIFICATION CONV-OPENSPEC-ARCHIVE; do
            if ! grep -q "$rule_id" "$config"; then
                gate_fail GATE-OPENSPEC-SCHEMA "$config 缺少 archive 指针 $rule_id"
            fi
        done

        if [ "$store" = Modules ]; then
            link_prefix='../../../.governance/openspec/schemas'
        else
            link_prefix='../../../../.governance/openspec/schemas'
        fi
        for schema in light-change full-change; do
            check_link GATE-OPENSPEC-SCHEMA "$store/openspec/schemas/$schema" \
                "$link_prefix/$schema" "$REPO_ROOT/.governance/openspec/schemas/$schema"
            if ! output=$(cd "$store" && run_openspec schema validate "$schema" --json 2>&1); then
                gate_fail GATE-OPENSPEC-SCHEMA "$store/$schema CLI validation 失败:$(printf '%s' "$output" | head -1)"
            fi
        done
        if ! output=$(cd "$store" && run_openspec validate --all --strict --no-interactive --json 2>&1); then
            gate_fail GATE-OPENSPEC-SCHEMA "$store content validation 失败:$(printf '%s' "$output" | head -1)"
        fi
    done <<EOF
$stores
EOF
}

check_shell_syntax() {
    shell_files=$(git ls-files 'scripts/*.sh' 'scripts/**/*.sh' '.githooks/*')
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        [ -f "$file" ] || continue
        if ! output=$(bash -n "$file" 2>&1); then
            gate_fail GATE-REQUIRED-VERIFICATION "$file shell syntax 无效:$(printf '%s' "$output" | head -1)"
        fi
    done <<EOF
$shell_files
EOF
}

check_static_toolchain_locks() {
    xcode_version=$(sed -n '1p' .xcode-version 2>/dev/null || true)
    xcode_build=$(sed -n '1p' .xcode-build-version 2>/dev/null || true)
    if ! printf '%s' "$xcode_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
        gate_fail GATE-TOOLCHAIN-VERSION ".xcode-version 必须是裸 marketing version"
    fi
    if ! printf '%s' "$xcode_build" | grep -Eq '^[A-Za-z0-9]+$'; then
        gate_fail GATE-TOOLCHAIN-VERSION ".xcode-build-version 必须是单行 build identity"
    fi
    for lock in tuist node openspec; do
        if ! grep -Eq "^(${lock}|\"npm:@fission-ai/openspec\")[[:space:]]*=" mise.toml; then
            case "$lock" in
                openspec)
                    grep -q 'npm:@fission-ai/openspec' mise.toml || gate_fail GATE-TOOLCHAIN-VERSION "mise.toml 缺少 OpenSpec lock"
                    ;;
                *) gate_fail GATE-TOOLCHAIN-VERSION "mise.toml 缺少 $lock lock" ;;
            esac
        fi
    done
}

report_checks() {
    bytes=$(wc -c < GOVERNANCE.md | tr -d ' ')
    lines=$(wc -l < GOVERNANCE.md | tr -d ' ')
    echo "ℹ️  CHECK-GOVERNANCE-SIZE:GOVERNANCE.md ${bytes} bytes / ${lines} lines"
    if [ "$bytes" -gt 16384 ] || [ "$lines" -gt 240 ]; then
        check_report CHECK-GOVERNANCE-SIZE "超过 advisory budget（16 KiB / 240 lines）"
    fi

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)
    if ! scripts/validate-branch-name.sh "$branch"; then
        check_report CHECK-BRANCH-NAME "$branch 不符合已声明的 change/<scope>-<verb-object>"
    fi
}

check_resolved_toolchain() {
    if ! command -v mise >/dev/null 2>&1; then
        gate_fail GATE-TOOLCHAIN-VERSION "缺少 mise"
        return
    fi

    node_lock=$(sed -n 's/^node[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' mise.toml)
    tuist_lock=$(sed -n 's/^tuist[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' mise.toml)
    openspec_lock=$(sed -n 's/^"npm:@fission-ai\/openspec"[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' mise.toml)

    node_actual=$(mise exec -- node --version 2>/dev/null || true)
    tuist_actual=$(mise exec -- tuist version 2>/dev/null || true)
    openspec_actual=$(mise exec -- openspec --version 2>/dev/null || true)
    [ "$node_actual" = "v$node_lock" ] || gate_fail GATE-TOOLCHAIN-VERSION "Node $node_actual != v$node_lock"
    [ "$tuist_actual" = "$tuist_lock" ] || gate_fail GATE-TOOLCHAIN-VERSION "Tuist $tuist_actual != $tuist_lock"
    [ "$openspec_actual" = "$openspec_lock" ] || gate_fail GATE-TOOLCHAIN-VERSION "OpenSpec $openspec_actual != $openspec_lock"

    if ! command -v xcodebuild >/dev/null 2>&1; then
        gate_fail GATE-TOOLCHAIN-VERSION "缺少 xcodebuild"
        return
    fi
    xcode_output=$(xcodebuild -version 2>/dev/null || true)
    xcode_actual=$(printf '%s\n' "$xcode_output" | sed -n 's/^Xcode //p')
    build_actual=$(printf '%s\n' "$xcode_output" | sed -n 's/^Build version //p')
    [ "$xcode_actual" = "$(sed -n '1p' .xcode-version)" ] || gate_fail GATE-TOOLCHAIN-VERSION "Xcode $xcode_actual 与 lock 不一致"
    [ "$build_actual" = "$(sed -n '1p' .xcode-build-version)" ] || gate_fail GATE-TOOLCHAIN-VERSION "Xcode build $build_actual 与 lock 不一致"

    if ! output=$(mise exec -- tuist generate --no-open 2>&1); then
        printf '%s\n' "$output" | tail -20 >&2
        gate_fail GATE-REQUIRED-VERIFICATION "tuist generate 失败:$(printf '%s' "$output" | tail -1)"
    fi
}

check_content_gates
if [ "$MODE" = staged ]; then
    if [ "$gate_failures" -ne 0 ]; then
        echo "❌ repo-doctor staged:$gate_failures Gate failure(s)" >&2
        exit 1
    fi
    exit 0
fi

for required_command in git bash find grep sed wc readlink realpath awk; do
    command -v "$required_command" >/dev/null 2>&1 || gate_fail GATE-REQUIRED-VERIFICATION "缺少 portable command:$required_command"
done

check_agent_links
check_openspec
check_shell_syntax
check_static_toolchain_locks
report_checks

if [ "$MODE" = local ] || [ "$MODE" = ci ]; then
    if [ "$MODE" = local ]; then
        hooks_path=$(git config --get core.hooksPath 2>/dev/null || true)
        [ "$hooks_path" = .githooks ] || gate_fail GATE-AGENT-ENTRY "core.hooksPath='$hooks_path'，请运行 scripts/bootstrap.sh"
    fi
    check_resolved_toolchain
fi

if [ "$gate_failures" -ne 0 ]; then
    echo "❌ repo-doctor $MODE:$gate_failures Gate failure(s)，$check_count Check warning(s)" >&2
    exit 1
fi
echo "✅ repo-doctor $MODE 通过（$check_count Check warning(s)）"
