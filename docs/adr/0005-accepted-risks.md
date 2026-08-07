# ADR-0005 已接受风险清单(建仓时点)

- 状态:accepted(2026-08-06)。逐条评审过,接受并配缓解措施;未来翻案须新 ADR 引用本条。

| # | 风险 | 接受理由 | 缓解 |
|---|---|---|---|
| 1 | Tuist 升级追赶负担(版本迭代快,manifest API 偶有破坏性变化) | 收益(ADR-0001)远大于升级成本 | mise 锁定版本;升级走 change 分支 + build-all 全绿 |
| 2 | 9-10 月换季张力(追 WWDC 新特性要 beta SDK,日常锁定稳定版) | 一年一次、窗口数周 | beta-smoke.sh 独立通道,非阻塞;稳定版发布后统一切换 |
| 3 | OpenSpec 年轻且自定义 schema 仍属实验能力 | 两套固定流程能降低日常流程税，且产品代码与测试不依赖 OpenSpec | 只保留 light/full 两套 schema；退出成本有界但不为零，真正退出时单次迁移 Markdown，不触碰产品接口 |
| 4 | 跨仓治理规则可能漂移 | 仓内单源能解决当前高频风险；跨仓统一尚无真实维护需求 | 本仓以 `GOVERNANCE.md` 为唯一来源；未来跨仓问题另行决策，不复制一套“总规则” |
| 5 | Claude Secret deny 对 Codex 无效 | 双 Agent 是既定工作流，但 Codex 当前没有仓库内可配置的等价防读能力 | 所有客户端共同执行 Git/doctor/CI 防入库；保留 Claude read/write deny；明确不宣称跨 Agent 防读 |
| 6 | 删除 App 级 Agent 入口会失去 Claude 子目录自动注入 | 重复入口的漂移和跨 Agent 差异比自动注入便利更难维护 | 根治理源按路径要求读取 App `CONTEXT.md`、`Project.swift` 和相关正式 specs；仓库根会话是运行前提 |

附:`.xcode-version` 暂时锁定 27.0(beta)——建仓机器唯一 Xcode;装回稳定版后改为锁定稳定版,见蓝图 §8.3。
