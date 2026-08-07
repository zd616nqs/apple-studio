# ADR-0006 中立治理源与受控派生材料

- 状态:accepted(2026-08-07)

仓库采用一个与具体 Agent 厂商无关的 `GOVERNANCE.md` 作为唯一人工治理源。根 `AGENTS.md` 与 `CLAUDE.md` 都是指向它的相对软链；工具配置、hook、脚本和 CI 只引用稳定规则 ID 并实现规则，不重新解释政策。治理要求统一分为 Gate、Check 和 Convention，不再用一个过载词同时指代不同强度；不引入自研 policy DSL。

选择中立单源会失去各 Agent 私有入口自由扩写规则的便利，但换来跨 Agent 相同语义和一次修改。治理执行分为三层：pre-commit 提供秒级反馈，repo doctor 执行完整健康检查，CI 给出不可绕过的最终结论。本地允许记录原因后应急绕过，但日常变更必须经 change 分支合并，不能把本地 hook 描述成绝对门禁。

工具必须嵌入规则时，只能保存最小的规则 ID 指针或使用指向唯一物理源的相对链接。只有工具格式确实无法消费链接时，才可以在独立 repo change 中引入可检查的生成副本；当前 OpenSpec schema 不需要这种例外。
