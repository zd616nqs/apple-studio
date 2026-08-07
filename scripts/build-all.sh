#!/usr/bin/env bash
#
# build-all.sh — 构建仓库里的全部 app
#
# 【为什么需要这个脚本】
# 共享层(Modules/)被所有 app 依赖:改了共享代码,某个 app 可能悄悄编译不过。
# 这个脚本就是"共享层改动后的全量验证":把每个 app 都构建一遍,
# 任何一个失败,整个脚本以非零退出码结束——这样它既能给人当体检工具,
# 也能给自动化流程当卡点。
#
# 【它做了什么】
#   1. tuist generate —— 先重新生成 workspace(工程声明可能刚被改过)
#   2. 遍历 Apps/ 下的每个 app,用 xcodebuild 构建(模拟器目标,不需要签名证书)
#
# 【注意】
# 只做"构建",不跑测试。跑测试用 scripts/test-affected.sh(只测受影响的部分,更快)。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 工具只用 mise 安装的锁定版本,不允许退回系统里来路不明的 tuist
# (否则"我这里能构建"可能只是因为版本恰好不同)
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
