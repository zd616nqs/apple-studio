#!/usr/bin/env bash
# beta 冒烟通道(ADR-0005 风险 2 的缓解):用 beta Xcode 做一次全量构建。
# 非阻塞:任何失败只报告,永远 exit 0——日常门禁仍钉在 .xcode-version 的稳定版。
# 禁缓存:一次性 DerivedData,不污染日常构建缓存。
# 用法:scripts/beta-smoke.sh [beta Xcode 路径,默认 /Applications/Xcode-beta.app]
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BETA_APP="${1:-/Applications/Xcode-beta.app}"
if [ ! -d "$BETA_APP" ]; then
    echo "ℹ️  beta-smoke:未找到 beta Xcode($BETA_APP),跳过"
    exit 0
fi
if ! command -v mise >/dev/null 2>&1; then
    echo "ℹ️  beta-smoke:缺少 mise,跳过(先跑 scripts/bootstrap.sh)"
    exit 0
fi

export DEVELOPER_DIR="$BETA_APP/Contents/Developer"
echo "▸ beta 工具链:$(xcodebuild -version | head -1)"

if ! mise exec -- tuist generate --no-open >/dev/null; then
    echo "⚠️  beta-smoke:tuist generate 失败(非阻塞,可能需等 Tuist 适配新 Xcode)"
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
        || echo "⚠️  beta-smoke:$scheme 在 beta 下构建失败(非阻塞,记下来等稳定版验证)"
done

echo "✅ beta-smoke 完成(仅报告,不当门禁)"
