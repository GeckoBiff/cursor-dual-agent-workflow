# docs/workflow — 双 Agent 工作流运行时目录

这个目录是 **arch 聊天** 和 **coder 聊天** 之间的交接区，所有文件都是人+AI 可读可写的。

## 文件速查

| 文件 | 生产者 | 说明 |
| ---- | ------ | ---- |
| `state.json` | hooks + arch/coder | 工作流状态机的单一事实源。agent 每次动作前读，动作后写 |
| `ARCHITECTURE.md` | arch | 本次任务的影响面分析、接口契约、风险点 |
| `PHASES.md` | arch | 阶段分解总览（每阶段的目标、DoD） |
| `phase-NN-plan.md` | arch | 每阶段开工前的详细设计（从 `_templates/phase-plan.template.md` 复制） |
| `phase-NN-summary.md` | coder 起稿 → arch 定稿 | 阶段总结（从模板复制） |
| `phase-NN-review.md` | arch | Review 结论（`APPROVED` / `REJECTED` + 整改项，从模板复制） |
| `_templates/` | - | 上面三种 per-phase 文件的模板 |

## 状态机速查

`state.json` 的 `status` 字段：

| 状态 | 含义 | 下一个预期动作 | 责任角色 |
| ---- | ---- | -------------- | -------- |
| `arch_design` | 接到新需求，正在做总体设计 | 完成 `ARCHITECTURE.md` + `PHASES.md` + `phase-01-plan.md` | arch |
| `phase_planning` | 准备进入某阶段，待写 plan | 写 `phase-NN-plan.md` | arch |
| `ready_for_coding` | plan 已就绪 | 切到 coder 聊天开始写代码 | coder |
| `coding` | coder 正在写代码 | 完成代码 + 起草 `phase-NN-summary.md` | coder |
| `awaiting_review` | 代码完成，等待 review | 切到 arch 聊天 | arch |
| `reviewing` | arch 正在 review | 写 `phase-NN-review.md` | arch |
| `rework` | review 未通过，需返工 | 切到 coder 聊天按 `state.rework_items` 整改 | coder |
| `phase_done` | 本阶段 APPROVED | 进入下一阶段 planning 或全部完成 | arch |
| `all_done` | 所有阶段完成 | — | — |

## 推荐操作节奏

1. arch 聊天 — `@role-arch` 给新需求 → 产出三件套 → state=ready_for_coding
2. coder 聊天 — `@role-coder` → 写代码 → draft summary → state=awaiting_review
3. arch 聊天 — `@role-arch` → review → 写 review.md → state 自动流转
4. 循环 2-3 直到 state=all_done

> 任何时候你都可以**手动改 `state.json`** 来强制回退或跳转，agent 下次 session 开始时会按新 state 行动。
