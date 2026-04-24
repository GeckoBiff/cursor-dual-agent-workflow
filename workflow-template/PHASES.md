# 阶段分解

> 由 **role-arch** 产出。将 `ARCHITECTURE.md` 拆成可独立交付、可独立 review 的小阶段。
> 经验值：单阶段工作量建议 < 半天，DoD 必须可验证。

## 阶段总览

| # | 标题 | 目标 | DoD（完成标准） | 依赖 | 预估 |
| -- | ---- | ---- | --------------- | ---- | ---- |
| 01 |      |      |                 | -    |      |
| 02 |      |      |                 | 01   |      |
| 03 |      |      |                 | 02   |      |

## Phase 01: <标题>

**目标**：

**范围（文件级）**：

- 新增/修改：`code/xxx.c`, `code/xxx.h`

**DoD**：

- [ ] 编译通过：`make` 无 error/warning 新增
- [ ] 功能点 A 可工作（如何验证）
- [ ] 功能点 B 可工作（如何验证）
- [ ] `phase-01-summary.md` 定稿

**开工前产出**：`phase-01-plan.md`（由 arch 写详细设计）
**完工后产出**：`phase-01-summary.md`（coder 起稿 → arch 定稿）+ `phase-01-review.md`（arch 出结论）

---

## Phase 02: <标题>

...

---

## 交付里程碑

- M1 (phases 01-NN)：
- M2 (phases ...)：
