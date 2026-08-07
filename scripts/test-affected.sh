#!/usr/bin/env bash
#
# test-affected.sh — 分类 Git 变更并测试受影响 App。
# 输入:可选 --list、--all、--base <ref>、--simulator-udid <UDID>。
# 输出:--list 返回 JSON；默认生成 workspace 并逐个运行受影响 scheme。
# 失败语义:依赖图、Simulator 或任一测试失败时非零退出。
# 规则:GATE-REQUIRED-VERIFICATION。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="run"
BASE=""
FORCE_ALL=0
SIMULATOR_UDID=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) MODE="list" ;;
        --all) FORCE_ALL=1 ;;
        --base)
            BASE="${2:?--base 需要一个 ref}"
            shift
            ;;
        --simulator-udid)
            SIMULATOR_UDID="${2:?--simulator-udid 需要一个 UDID}"
            shift
            ;;
        *)
            echo "未知参数:$1(支持 --list / --all / --base <ref> / --simulator-udid <UDID>)" >&2
            exit 2
            ;;
    esac
    shift
done

# 三个依赖:mise 管工具版本,jq 解析 JSON,python3 做依赖图运算
for tool in mise jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ 缺少 $tool(mise 用 scripts/bootstrap.sh 安装;jq/python3 随 macOS 开发工具提供)" >&2
        exit 1
    fi
done

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)

if [ "$FORCE_ALL" -eq 1 ]; then
    changed=Workspace.swift
    BASE=""
else
    if [ -n "$BASE" ]; then
        BASE=$(scripts/resolve-comparison-base.sh "$BASE")
    else
        BASE=$(scripts/resolve-comparison-base.sh)
    fi
    changed=$(
        {
            git diff --name-only "$BASE" HEAD
            git diff --name-only
            git diff --cached --name-only
            git ls-files --others --exclude-standard
        } | sort -u | grep -v '^$' || true
    )
fi

if [ -z "$changed" ]; then
    if [ "$MODE" = "list" ]; then
        printf '{"branch":"%s","changed":[],"affected_apps":[],"affected_modules":[],"trigger_all":null}\n' "$branch"
    else
        echo "✅ test-affected:没有改动文件,无需测试"
    fi
    exit 0
fi

# 让 Tuist 导出当前依赖图(JSON),后面用它反查"模块 → 依赖它的 app"
graph_dir=$(mktemp -d)
trap 'rm -rf "$graph_dir"' EXIT
# 标准错误不做静音:依赖图导出失败(比如还没运行 tuist install)时,错误必须能被看见
mise exec -- tuist graph -f json -o "$graph_dir" >/dev/null

# 说明:python3 - 的脚本正文占用了标准输入(heredoc),
# 所以改动文件清单只能通过环境变量传进去,不能再用管道
result=$(CHANGED="$changed" python3 - "$graph_dir/graph.json" "$branch" <<'PY'
import json
import os
import sys

graph_path, branch = sys.argv[1], sys.argv[2]
changed = [line.strip() for line in os.environ.get("CHANGED", "").splitlines() if line.strip()]

with open(graph_path) as f:
    data = json.load(f)

# Tuist 导出的 dependencies 是"键值交替"的数组:
# {目标 A 的描述}, [A 的依赖列表], {目标 B 的描述}, [B 的依赖列表] …
# 这里把它整理成普通的邻接表
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


# 从某个 app 出发,沿依赖边一路走到底,收集它直接和间接依赖的全部目标
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


# 反查:哪些 app 的依赖集合里含有指定的共享模块
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
    if "/openspec/" in f or f.startswith(".governance/"):
        continue
    if f.startswith("Apps/") and len(parts) > 1 and parts[1] in all_apps:
        if len(parts) >= 3 and parts[2] == "Resources":
            affected.add(parts[1])
        elif not f.endswith(".md"):
            affected.add(parts[1])
    elif f.startswith("Modules/"):
        if len(parts) >= 3:
            affected_modules.add(parts[1])
        else:
            trigger_all = f  # Modules 顶层文件(如 Project.swift)变了 → 所有 app 都受影响
    elif (
        f.startswith("Tuist/")
        or f.startswith("scripts/")
        or f
        in (
            "Tuist.swift",
            "Workspace.swift",
            "mise.toml",
            ".xcode-version",
            ".xcode-build-version",
        )
    ):
        trigger_all = f
    # 其余 Markdown/治理文件不影响 App 构建产物。

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
    echo "✅ test-affected:改动不影响任何 app,无需测试"
    exit 0
fi

# xcodebuild 始终消费 UDID；即使多个 runtime 有同名设备也不会产生歧义。
if [ -n "$SIMULATOR_UDID" ]; then
    sim="$SIMULATOR_UDID"
else
    sim=$(scripts/select-ios-simulator.sh)
fi

echo "▸ tuist generate"
mise exec -- tuist generate --no-open >/dev/null

fail=0
for scheme in $apps; do
    echo "▸ 测试 $scheme(Simulator UDID:$sim)"
    xcodebuild -workspace AppleStudio.xcworkspace -scheme "$scheme" \
        -destination "platform=iOS Simulator,id=$sim" \
        -quiet CODE_SIGNING_ALLOWED=NO test || { echo "❌ $scheme 测试失败"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ test-affected 全部通过:$(echo "$apps" | tr '\n' ' ')"
