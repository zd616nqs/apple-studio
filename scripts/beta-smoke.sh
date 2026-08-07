#!/usr/bin/env bash
#
# beta-smoke.sh — 用指定或默认 beta Xcode 构建全部 App。
# 输入:可选 Xcode.app 路径。输出:逐 App 诊断。
# 失败语义:缺工具或构建失败只报告，始终不阻塞；DerivedData 使用临时目录。
# 规则:无（独立于 GATE-TOOLCHAIN-VERSION 的非权威兼容性观察）。
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
