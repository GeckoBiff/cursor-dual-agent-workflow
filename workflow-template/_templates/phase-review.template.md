# Phase NN Review — <阶段标题>

> 由 **role-arch** 产出。结论机器可读，`on-after-edit.ps1` 会解析本文件。
> 复制此模板为 `docs/workflow/phase-NN-review.md`。

---
phase: NN
reviewer: arch
reviewed_at: <ISO-8601>
verdict: APPROVED
---

<!--
verdict 必须是 APPROVED 或 REJECTED 之一。
REJECTED 时必须填写 "整改项" 列表，每项尽量可执行。
-->

## 1. 对照 plan.md 的 DoD 核查

- [ ] DoD 1：<通过/不通过 + 证据>
- [ ] DoD 2：
- [ ] DoD 3：

## 2. 代码 Review 要点

### 2.1 架构一致性

<!-- 是否贴合 ARCHITECTURE.md 的接口契约/数据结构 -->

### 2.2 正确性

<!-- 逻辑、边界、错误处理 -->

### 2.3 嵌入式专项

- 内存/栈：
- ISR / 可重入：
- 寄存器时序：
- 编译告警：

### 2.4 可维护性

<!-- 命名、注释、模块化 -->

## 3. 整改项（仅 REJECTED 时填写）

<!--
格式：每条一行，以 "- [ ] " 开头，on-after-edit.ps1 会把整改项复制到 state.json 的 rework_items。
-->

- [ ]
- [ ]

## 4. 通过后事项（仅 APPROVED 时填写）

- 下阶段建议关注：
- 技术债登记：
