# Prompt: 项目接入（project-bootstrap）

> 用途：把 AICoding-RULE 基线接入一个新项目或尚无规则体系的既有项目。
> 复制本提示词给 AI 执行窗口，替换 {{...}} 后使用。

------

## 任务

为项目 `{{PROJECT_PATH}}` 接入 AICoding-RULE 规则基线（基线位置：`{{BASELINE_PATH}}`）。

## 边界

- 不修改任何业务代码、数据库、生产配置。
- 项目已有的 CLAUDE.md / AGENTS.md / docs/ai 文件**禁止直接覆盖**；只允许生成建议 diff 供人工裁决。
- 项目事实必须写入 05_PROJECT_CONTEXT.md 与入口文件项目区，禁止写入规则区块。

## 步骤

1. 先审计：运行 `Audit-AICodingRule.ps1 -ProjectPath {{PROJECT_PATH}}`（或手工检查等价项），列出已有/缺失的规则文件。
2. 探索项目事实：按 core/01 项目级阅读要求，确认项目类型、组件与端口、环境边界、数据库、鉴权、高风险区域。禁止无目的遍历业务代码。
3. 安装缺失文件：运行 `Install-AICodingRule.ps1 -ProjectPath {{PROJECT_PATH}} -WhatIf` 审阅计划，确认后去掉 -WhatIf 执行（建议加 -Backup）。
4. 填写项目层：05_PROJECT_CONTEXT.md 的 14 节、入口文件的硬约束/安全底线/高风险追加区、需要启用的 adapters（登记进 .aicoding-rule.json）。
5. 一致性检查：CLAUDE.md 与 AGENTS.md 语义一致；README 导航路径有效；`git diff --check` 干净。
6. 输出报告：安装了什么、跳过了什么（已存在）、项目层填了什么、待人工确认什么。

## 完成标准

- 项目拥有自包含规则入口（不依赖跨目录读取基线）。
- 项目事实与通用规则分层清晰。
- 未覆盖任何既有文件。
