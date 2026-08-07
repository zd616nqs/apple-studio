#!/usr/bin/env bash
#
# bootstrap.sh — 初始化开发环境(clone 仓库之后运行的第一条命令)
#
# 【为什么需要这个脚本】
# 本仓库依赖两个命令行工具:Tuist(生成 Xcode 工程)和 openspec(管理行为文档)。
# 如果每个人/每台机器手动安装,版本迟早不一致,构建结果就不可复现。
# 因此所有工具的版本都写在 mise.toml 里,由 mise 统一安装到锁定的版本,
# 本脚本就是"把这套约定在一台新机器上落实"的一键入口。
#
# 【它做了哪四件事】
#   1. mise install  —— 按 mise.toml 安装锁定版本的 Tuist / node / openspec
#   2. 启用 git 钩子 —— 让 .githooks/pre-commit 里的提交检查生效
#                       (钩子文件在仓库里受版本管理,但 git 默认不启用,需要这一步)
#   3. tuist install —— 下载 Tuist/Package.swift 里声明的第三方库
#   4. tuist generate —— 生成 AppleStudio.xcworkspace(生成物,不入库)
#
# 【边界】
# 只改动仓库内部和 git 本地配置,不写任何用户主目录/系统目录的配置文件
# (mise 自身会把工具安装到 ~/.local/share/mise,那是包管理器的常规行为,不属于配置污染)。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# mise 是唯一需要预先手动安装的工具,缺了它后面全部无从谈起
if ! command -v mise >/dev/null 2>&1; then
    echo "❌ 缺少 mise(工具版本管理器)。请先安装:brew install mise" >&2
    exit 1
fi

echo "▸ mise trust + install(按 mise.toml 安装锁定版本的 Tuist / openspec)"
# trust:mise 出于安全默认不信任新目录的配置文件,首次需要显式信任本仓库的 mise.toml
mise trust --quiet
mise install

echo "▸ 启用版本管理的 git 钩子(.githooks/)"
git config core.hooksPath .githooks

echo "▸ tuist install(下载 Tuist/Package.swift 声明的第三方依赖)"
mise exec -- tuist install

echo "▸ tuist generate(生成 Xcode workspace)"
mise exec -- tuist generate --no-open

echo "✅ 环境初始化完成。下一步可运行:scripts/build-all.sh 验证全部 app 能构建"
