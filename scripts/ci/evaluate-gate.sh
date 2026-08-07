#!/usr/bin/env bash
# evaluate-gate.sh — 汇总 classify/static/apple 三个 job 的结果。
# 输入:classify result、apple_required、static result、apple result。
# 输出:最终 gate 的可读裁决。
# 失败语义:除两种显式合法状态外全部非零，避免 skipped 被泛化为成功。
set -uo pipefail

if [ "$#" -ne 4 ]; then
    echo "用法:scripts/ci/evaluate-gate.sh <classify-result> <apple-required> <static-result> <apple-result>" >&2
    exit 2
fi

classify_result=$1
apple_required=$2
static_result=$3
apple_result=$4

if [ "$classify_result" != success ]; then
    echo "GATE-MAIN-CI:classify=$classify_result，必须为 success" >&2
    exit 1
fi
if [ "$static_result" != success ]; then
    echo "GATE-MAIN-CI:static=$static_result，必须为 success" >&2
    exit 1
fi

case "$apple_required:$apple_result" in
    false:skipped)
        echo "GATE-MAIN-CI:通过（明确无需 Apple，apple job 合法跳过）"
        ;;
    true:success)
        echo "GATE-MAIN-CI:通过（Apple 验证已成功）"
        ;;
    *)
        echo "GATE-MAIN-CI:非法状态 apple_required='$apple_required', apple='$apple_result'" >&2
        exit 1
        ;;
esac
