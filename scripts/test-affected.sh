#!/usr/bin/env bash
# 只测受影响范围:git diff 分类 → tuist graph 反查 → 逐 app 跑测试。
# 用法:
#   scripts/test-affected.sh              # 跑受影响 app 的测试(无受影响则直接绿)
#   scripts/test-affected.sh --list       # 只输出受影响范围 JSON(供 review/tdd 类 skill 消费)
#   scripts/test-affected.sh --base <ref> # 显式指定 diff 基准
# 默认基准:main 上 = 未提交改动;其他分支 = merge-base(main, HEAD) 起 + 未提交改动。
# 分类规则(蓝图 §3.5):Apps/X→X;Modules/M→依赖图反查;Modules 根/Tuist/Workspace/工具链钉版→全部。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="run"
BASE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) MODE="list" ;;
        --base)
            BASE="${2:?--base 需要一个 ref}"
            shift
            ;;
        *)
            echo "未知参数:$1(支持 --list / --base <ref>)" >&2
            exit 2
            ;;
    esac
    shift
done

for tool in mise jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ 缺少 $tool(mise 用 scripts/bootstrap.sh 装;jq/python3 随 macOS/CLT 提供)" >&2
        exit 1
    fi
done

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)

changed=$(
    {
        if [ -n "$BASE" ]; then
            git diff --name-only "$BASE"
        elif [ "$branch" != "main" ] && git rev-parse --verify -q main >/dev/null; then
            git diff --name-only "$(git merge-base main HEAD)"
        fi
        git diff --name-only
        git diff --cached --name-only
        git ls-files --others --exclude-standard
    } | sort -u | grep -v '^$' || true
)

if [ -z "$changed" ]; then
    if [ "$MODE" = "list" ]; then
        printf '{"branch":"%s","changed":[],"affected_apps":[],"affected_modules":[],"trigger_all":null}\n' "$branch"
    else
        echo "✅ test-affected:无变更文件,无需测试"
    fi
    exit 0
fi

graph_dir=$(mktemp -d)
trap 'rm -rf "$graph_dir"' EXIT
# stderr 不吞:graph 失败(如未 tuist install)时 set -e 中止,错误必须可见
mise exec -- tuist graph -f json -o "$graph_dir" >/dev/null

# 注意:python3 - 的程序体走 stdin(heredoc),数据只能走环境变量,不能再用管道
result=$(CHANGED="$changed" python3 - "$graph_dir/graph.json" "$branch" <<'PY'
import json
import os
import sys

graph_path, branch = sys.argv[1], sys.argv[2]
changed = [line.strip() for line in os.environ.get("CHANGED", "").splitlines() if line.strip()]

with open(graph_path) as f:
    data = json.load(f)

# dependencies 是键值交替的数组:{target 描述}, [它的依赖], {target}, [依赖] …
deps = data.get("dependencies", [])
adj = {}


def tid(node):
    t = node.get("target", {})
    return (t.get("name", ""), t.get("path", ""))


i = 0
while i < len(deps) - 1:
    key, val = deps[i], deps[i + 1]
    if isinstance(key, dict) and isinstance(val, list):
        adj[tid(key)] = [tid(x) for x in val if isinstance(x, dict)]
        i += 2
    else:
        i += 1

all_apps = sorted(
    d for d in os.listdir("Apps") if os.path.isdir(os.path.join("Apps", d))
)


def closure(app):
    start = [k for k in adj if k[0] == app and k[1].endswith(f"/Apps/{app}")]
    seen, queue = set(start), list(start)
    while queue:
        node = queue.pop()
        for dep in adj.get(node, []):
            if dep not in seen:
                seen.add(dep)
                queue.append(dep)
    return seen


app_closures = {app: closure(app) for app in all_apps}


def apps_depending_on_module(module):
    return [
        app
        for app, nodes in app_closures.items()
        if any(n[0] == module and n[1].endswith("/Modules") for n in nodes)
    ]


affected = set()
affected_modules = set()
trigger_all = None

for f in changed:
    parts = f.split("/")
    if f.startswith("Apps/") and len(parts) > 1 and parts[1] in all_apps:
        affected.add(parts[1])
    elif f.startswith("Modules/"):
        if len(parts) >= 3:
            affected_modules.add(parts[1])
        else:
            trigger_all = f  # Modules 根(如 Project.swift)→ 全部
    elif f.startswith("Tuist/") or f in ("Workspace.swift", "mise.toml", ".xcode-version"):
        trigger_all = f
    # 其余(docs/.claude/.githooks/CLAUDE.md/openspec/scripts)不影响 app 构建产物

if trigger_all:
    affected = set(all_apps)
else:
    for m in affected_modules:
        affected.update(apps_depending_on_module(m))

print(
    json.dumps(
        {
            "branch": branch,
            "changed": changed,
            "affected_apps": sorted(affected),
            "affected_modules": sorted(affected_modules),
            "trigger_all": trigger_all,
        },
        ensure_ascii=False,
    )
)
PY
)

if [ "$MODE" = "list" ]; then
    echo "$result"
    exit 0
fi

apps=$(echo "$result" | jq -r '.affected_apps[]')
if [ -z "$apps" ]; then
    echo "✅ test-affected:变更不影响任何 app,无需测试"
    exit 0
fi

sim=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
names = [d["name"] for devs in data["devices"].values() for d in devs if d["name"].startswith("iPhone")]
print(names[0] if names else "")
')
if [ -z "$sim" ]; then
    echo "❌ 找不到可用 iPhone 模拟器" >&2
    exit 1
fi

echo "▸ tuist generate"
mise exec -- tuist generate --no-open >/dev/null

fail=0
for scheme in $apps; do
    echo "▸ 测试 $scheme(模拟器:$sim)"
    xcodebuild -workspace AppleStudio.xcworkspace -scheme "$scheme" \
        -destination "platform=iOS Simulator,name=$sim" \
        -quiet CODE_SIGNING_ALLOWED=NO test || { echo "❌ $scheme 测试失败"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ test-affected 全绿:$(echo "$apps" | tr '\n' ' ')"
