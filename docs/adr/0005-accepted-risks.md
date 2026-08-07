# ADR-0005 已接受风险清单(建仓时点)

- 状态:accepted(2026-08-06)。逐条评审过,接受并配缓解措施;未来翻案须新 ADR 引用本条。

| # | 风险 | 接受理由 | 缓解 |
|---|---|---|---|
| 1 | Tuist 升级追赶负担(版本迭代快,manifest API 偶有破坏性变化) | 收益(ADR-0001)远大于升级成本 | mise 锁定版本;升级走 change 分支 + build-all 全绿 |
| 2 | 9-10 月换季张力(追 WWDC 新特性要 beta SDK,日常锁定稳定版) | 一年一次、窗口数周 | beta-smoke.sh 独立通道,非阻塞;稳定版发布后统一切换 |
| 3 | OpenSpec 年轻(官方自称 rough;上游 bug 如 #1212 stale-specs) | 有"不绑死"退出设计 | 契约区纯 markdown,弃用时 specs 原地退化为文档,迁移成本零;禁 ff 红线 |
| 4 | 跨仓红线漂移(三个生态仓各持红线副本) | 仓内软链已消灭仓内漂移;跨仓频率低 | 建仓时抄冻结蓝图;蓝图 §8 记录偏差 |
| 5 | Claude hooks 对 Codex 无效 | 双 agent 是既定工作流 | 主防线下沉到工具中立 git pre-commit;guard 仅作 Claude 侧提前预警 |

附:`.xcode-version` 暂时锁定 27.0(beta)——建仓机器唯一 Xcode;装回稳定版后改为锁定稳定版,见蓝图 §8.3。
