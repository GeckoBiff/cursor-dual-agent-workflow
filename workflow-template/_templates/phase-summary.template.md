# Phase NN Summary — <阶段标题>

> 由 **role-coder** 起草（draft），由 **role-arch** 在 review 通过后定稿。
> 起草时在头部写 `status: draft`，arch 定稿后改为 `status: finalized`。

---
status: draft
phase: NN
author_draft: coder
author_final: arch
---

## 1. 交付内容

<!-- 一句话概括本阶段实际交付了什么，与 plan.md 的目标对齐情况 -->

## 2. 改动清单

| 文件 | 改动类型 | 行数 ± | 说明 |
| ---- | -------- | ------ | ---- |
|      | 新增/修改/删除 |        |      |

## 3. 关键实现决策

<!-- coder 在实现过程中做的值得记录的选择：为什么 A 不用 B -->

## 4. 与 plan.md 的偏差（DEVIATION）

<!-- 如果完全贴合 plan，写 "无"。任何偏离都必须在这里记录 -->

- ⚠ DEVIATION 1：
  - 偏离内容：
  - 原因：
  - 影响面：

## 5. 自测结果

### 5.1 编译

```
<贴 make 输出的最后若干行，含 warning/error 数量>
```

### 5.2 功能验证

- [ ] plan 测试点 1：<结果>
- [ ] plan 测试点 2：<结果>

## 6. 待 arch 决策的问题（阻塞项）

<!-- 如果没有，写 "无"。有阻塞项 → status 必须是 awaiting_review -->

1.

## 7. 遗留项 / 后续建议

<!-- 非阻塞但值得记录的技术债、优化点，可能拆成新 phase -->

## 8. Review 结论（arch 定稿时填）

- Verdict：APPROVED / REJECTED
- Review 文件：`phase-NN-review.md`
- 定稿日期：
