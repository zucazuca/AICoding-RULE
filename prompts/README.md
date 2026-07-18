# Prompts

本目录保存可复制执行的任务提示词。它们按需使用，不属于 core，也不进入默认 Required Reading。

## 基线维护

| Prompt | 用途 |
|---|---|
| [project-bootstrap](project-bootstrap.md) | 为项目接入规则基线 |
| [baseline-rule-audit](baseline-rule-audit.md) | 只读审计项目规则与基线偏差 |
| [baseline-doc-refactor](baseline-doc-refactor.md) | 重构已腐化的项目上下文文档 |
| [periodic-maintenance](periodic-maintenance.md) | 周期性维护规则和上下文 |
| [audit-only](audit-only.md) | 快速只读健康检查 |

## 可选高级工作流

Three-Authority VibeCoding Governance 默认关闭。启用条件和状态机见[工作流规范](../workflows/three-authority-vibecoding/README.md)。

| 角色 | Prompt |
|---|---|
| 审批窗口 | [approver-window](three-authority-vibecoding/approver-window.md) |
| 执行窗口 | [executor-window](three-authority-vibecoding/executor-window.md) |
| 测试窗口 | [tester-window](three-authority-vibecoding/tester-window.md) |
