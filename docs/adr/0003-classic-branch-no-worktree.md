# ADR-0003 经典 feature 分支,不默认 worktree

- 状态:accepted(2026-08-06)
- 背景:agent 时代的并行开发常配 worktree-per-change;用户实测认为 worktree 的
  git 操作成本(创建/切换/清理/心智)对 solo 开发者过高。

## 决策

- 1 change = 1 branch = 1 PR,分支 `change/<app>-<slug>`;rebase main 后 merge --no-ff
- worktree 仅作临时逃生舱:真需要同时开两个互相冲突的变更时手动开,用完即删
- OpenSpec changes/ 目录天然按变更隔离,同分支串行开发冲突面已经很小

## 后果

- ✅ git 心智负担最小;历史线性可读(--no-ff 保留变更边界)
- ⚠️ 并行度受限:同一时刻主力只推进一个 change(solo 场景实际无损)
