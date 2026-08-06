#!/usr/bin/env bash
# 生成 workspace 并构建全部 app(模拟器目标,不签名)。任一失败即非零退出。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 工具链只走 mise 钉版,不回退系统里未钉版的 tuist
if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise。先跑 scripts/bootstrap.sh" >&2
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
    # 目前全部 app 都是 iOS;首个 macOS 目标 app 出现时需按 scheme 平台分派 destination
    xcodebuild -workspace "$WORKSPACE" -scheme "$scheme" \
        -destination 'generic/platform=iOS Simulator' \
        -quiet CODE_SIGNING_ALLOWED=NO build || { echo "❌ $scheme 构建失败"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "✅ build-all 全绿($count 个 app)"
