# ADR-0007 分级 OpenSpec 工作流

- 状态:accepted(2026-08-07)

仓库采用两套项目内 OpenSpec schema：轻量行为变更只经过 specs、apply 和 archive，完整变更经过 proposal、specs、design、tasks、apply 和 archive；非行为修改不创建 OpenSpec change。OpenSpec 1.8 的自定义 schema 仍属实验能力，因此只维护这两套静态 DAG，不模拟当前不支持的自定义 operation。变更等级由治理源中的确定性条件判定，边界不清时升级，维护者可显式覆盖。

两套 schema 的唯一物理源位于 `.governance/openspec/schemas/`，三个产品 store 通过仓库内相对目录软链消费。Store config 只维护领域上下文、完整流程默认值和 OpenSpec 原生格式要求的 archive 规则 ID 指针。这个设计牺牲了 store 的完全独立复制能力，换取 schema 内容不能漂移，并避免自研同步脚本。
