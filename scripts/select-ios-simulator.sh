#!/usr/bin/env bash
# select-ios-simulator.sh — 从当前可用 iOS runtimes 中确定一个 iPhone UDID。
# 输入:可选 simctl devices JSON 文件；省略时调用 xcrun simctl。
# 输出:仅在 stdout 输出 UDID，选择说明写入 stderr。
# 失败语义:JSON 无效或没有可用 iPhone 时非零。
set -uo pipefail

if [ "$#" -gt 1 ]; then
    echo "用法:scripts/select-ios-simulator.sh [simctl-devices.json]" >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ 缺少 python3，无法解析 Simulator 清单" >&2
    exit 1
fi

source_file="${1:-}"
if [ -n "$source_file" ]; then
    if [ ! -f "$source_file" ]; then
        echo "❌ Simulator JSON 不存在:$source_file" >&2
        exit 1
    fi
    simulator_json=""
else
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "❌ 缺少 xcrun，无法读取 Simulator 清单" >&2
        exit 1
    fi
    if ! simulator_json=$(xcrun simctl list devices available -j); then
        echo "❌ simctl 无法读取可用 Simulator" >&2
        exit 1
    fi
fi

SIMULATOR_JSON="$simulator_json" python3 - "$source_file" <<'PY'
import json
import os
import re
import sys

source = sys.argv[1]
try:
    if source:
        with open(source, encoding="utf-8") as handle:
            data = json.load(handle)
    else:
        data = json.loads(os.environ["SIMULATOR_JSON"])
except (OSError, KeyError, json.JSONDecodeError) as error:
    print(f"❌ Simulator JSON 无效:{error}", file=sys.stderr)
    raise SystemExit(1)

candidates = []
prefix = "com.apple.CoreSimulator.SimRuntime.iOS-"
for runtime, devices in data.get("devices", {}).items():
    if not runtime.startswith(prefix):
        continue
    raw_version = runtime[len(prefix):]
    if not re.fullmatch(r"[0-9-]+", raw_version):
        continue
    version = tuple(int(part) for part in raw_version.split("-"))
    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid", "")
        if name.startswith("iPhone") and udid and device.get("isAvailable", True):
            candidates.append((version, name, udid))

if not candidates:
    print("❌ 找不到可用的 iPhone Simulator", file=sys.stderr)
    raise SystemExit(1)

latest_version = max(candidate[0] for candidate in candidates)
latest = sorted(
    (candidate for candidate in candidates if candidate[0] == latest_version),
    key=lambda candidate: (candidate[1], candidate[2]),
)
version, name, udid = latest[0]
print(f"ℹ️  选择 iOS {'.'.join(map(str, version))} {name} ({udid})", file=sys.stderr)
print(udid)
PY
