#!/usr/bin/env bash
#
# beta-smoke.sh — 用 beta 版 Xcode 做一次全量构建的提前体检
#
# 【背景】
# 日常构建锁定在稳定版 Xcode(.xcode-version),保证发版可靠。
# 但每年 6-9 月苹果发 beta 期间,新系统/新 SDK 的适配问题越早发现越好。
# 这个脚本提供一条独立通道:用 beta 版 Xcode 把所有 app 构建一遍,
# 提前暴露"新 SDK 下编译不过"这类问题。
#
# 【两条设计原则】
#   1. 永不阻塞:任何失败只打印报告,脚本永远以 0 退出——
#      beta 下构建失败是"情报"(记下来等适配),不是"事故",不应卡住任何流程。
#   2. 不碰缓存:用一次性的临时 DerivedData 目录,
#      避免 beta 工具链的产物污染日常构建的缓存。
#
# 【用法】
#   scripts/beta-smoke.sh                          # 默认找 /Applications/Xcode-beta.app
#   scripts/beta-smoke.sh /Applications/Xcode-27.1-beta.app   # 或指定路径
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BETA_APP="${1:-/Applications/Xcode-beta.app}"
if [ ! -d "$BETA_APP" ]; then
    echo "ℹ️  beta-smoke:未找到 beta 版 Xcode($BETA_APP),跳过"
    exit 0
fi
if ! command -v mise >/dev/null 2>&1; then
    echo "ℹ️  beta-smoke:缺少 mise,跳过(请先运行 scripts/bootstrap.sh)"
    exit 0
fi

# DEVELOPER_DIR 是 Apple 官方的工具链切换开关:后续 xcodebuild 都会用 beta 版
export DEVELOPER_DIR="$BETA_APP/Contents/Developer"
echo "▸ beta 工具链:$(xcodebuild -version | head -1)"

if ! mise exec -- tuist generate --no-open >/dev/null; then
    echo "⚠️  beta-smoke:tuist generate 失败(不阻塞;新版 Xcode 刚发布时 Tuist 可能尚未适配)"
    exit 0
fi

derived=$(mktemp -d)
trap 'rm -rf "$derived"' EXIT

for app_dir in Apps/*/; do
    scheme="$(basename "$app_dir")"
    echo "▸ beta 构建 $scheme"
    xcodebuild -workspace AppleStudio.xcworkspace -scheme "$scheme" \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$derived" \
        -quiet CODE_SIGNING_ALLOWED=NO build \
        || echo "⚠️  beta-smoke:$scheme 在 beta 下构建失败(不阻塞,记录下来等稳定版发布后适配)"
done

echo "✅ beta-smoke 完成(只报告,不拦截)"
