#!/usr/bin/env bash
#
# test-affected.sh — 只对"受本次改动影响的 app"跑测试
#
# 【为什么需要这个脚本】
# monorepo 里 app 会越来越多,每次改动都全量跑所有测试太慢。
# 但"我改的这个文件影响了哪些 app"靠人脑判断又容易漏——尤其是改共享层时。
# 这个脚本把判断交给依赖图:改动文件 → 归类 → 用 Tuist 的依赖图反查
# → 得出受影响的 app 清单 → 只对它们跑测试。
# 改共享模块会自动带出所有依赖它的 app(含间接依赖),改单个 app 则只测它自己。
#
# 【用法】
#   scripts/test-affected.sh              对受影响的 app 跑测试(无受影响则直接通过)
#   scripts/test-affected.sh --list       只输出受影响范围的 JSON,不跑测试
#                                         (给其他自动化工具/skill 提供数据)
#   scripts/test-affected.sh --base <ref> 显式指定比较基准(默认见下)
#
# 【改动范围怎么算】
#   在 main 分支上:未提交的改动(含新建但未跟踪的文件——否则新写的测试文件会被漏掉)
#   在其他分支上:分支与 main 的分叉点之后的全部提交 + 未提交改动
#
# 【文件怎么归类】(与蓝图约定一致)
#   Apps/X/ 下的文件            → 影响 app X
#   Modules/M/ 下的文件         → 用依赖图反查哪些 app 依赖模块 M(含间接依赖)
#   Modules 顶层 / Tuist/ /
#   Workspace.swift / 版本锁定文件 → 影响全部 app(工程结构或工具链变了,谁都跑不掉)
#   其余(文档、流程配置、脚本)   → 不影响 app 构建产物,不触发测试
#
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

# 三个依赖:mise 管工具版本,jq 解析 JSON,python3 做依赖图运算
for tool in mise jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ 缺少 $tool(mise 用 scripts/bootstrap.sh 安装;jq/python3 随 macOS 开发工具提供)" >&2
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
    if f.startswith("Apps/") and len(parts) > 1 and parts[1] in all_apps:
        affected.add(parts[1])
    elif f.startswith("Modules/"):
        if len(parts) >= 3:
            affected_modules.add(parts[1])
        else:
            trigger_all = f  # Modules 顶层文件(如 Project.swift)变了 → 所有 app 都受影响
    elif f.startswith("Tuist/") or f in ("Workspace.swift", "mise.toml", ".xcode-version"):
        trigger_all = f
    # 其余文件(文档、.claude、.githooks、CLAUDE.md、openspec、scripts)不影响 app 构建产物

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

# 跑测试需要一台具体的模拟器,从可用设备里选第一台 iPhone
sim=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
names = [d["name"] for devs in data["devices"].values() for d in devs if d["name"].startswith("iPhone")]
print(names[0] if names else "")
')
if [ -z "$sim" ]; then
    echo "❌ 找不到可用的 iPhone 模拟器" >&2
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
echo "✅ test-affected 全部通过:$(echo "$apps" | tr '\n' ' ')"
