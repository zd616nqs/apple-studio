#!/usr/bin/env bash
#
# build-all.sh — 重新生成 workspace 并构建 Apps/ 下的全部 App。
# 输入:Tuist manifest 与锁定依赖。输出:每个 scheme 的无签名 Simulator build。
# 失败语义:收集 App 构建结果，任一失败最终非零退出；不运行测试。
# 规则:GATE-REQUIRED-VERIFICATION、GATE-TOOLCHAIN-VERSION。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise。请先运行 scripts/bootstrap.sh" >&2
    exit 1
fi

echo "▸ tuist generate"
mise exec -- tuist generate --no-open

WORKSPACE="AppleStudio.xcworkspace"
fail=0
count=0
for app_dir in Apps/*/; do
    scheme="$(basename "$app_dir")"
    count=$((count + 1))
    echo "▸ 构建 $scheme"
    # 目前全部 app 都是 iOS;将来出现 macOS 目标的 app 时,这里需要按 scheme 所属平台选择 destination
    xcodebuild -workspace "$WORKSPACE" -scheme "$scheme" \
        -destination 'generic/platform=iOS Simulator' \
        -quiet CODE_SIGNING_ALLOWED=NO build || { echo "❌ $scheme 构建失败"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ build-all 全部通过($count 个 app)"
