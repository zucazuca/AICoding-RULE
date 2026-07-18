# Prompt: 项目接入（project-bootstrap）

> 用途：把 AICoding-RULE 基线接入一个新项目或尚无规则体系的既有项目。
> 复制本提示词给 AI 执行窗口，替换 {{...}} 后使用。
> 执行前提：AI 当前工作目录必须是用户提供的 AICoding-RULE 基线仓库根目录。

------

## 任务

为相对路径 `{{PROJECT_RELATIVE_PATH}}` 指向的项目接入 AICoding-RULE 规则基线。

`{{PROJECT_RELATIVE_PATH}}` 必须是从当前基线仓库根目录出发的相对路径，例如 `..\你的项目`；所有命令都必须用双引号包裹该路径。

## 边界

- 不修改任何业务代码、数据库、生产配置。
- 项目已有的 CLAUDE.md / AGENTS.md / docs/ai 文件**禁止直接覆盖**；只允许生成建议 diff 供人工裁决。
- 项目事实必须写入 05_PROJECT_CONTEXT.md 与入口文件项目区，禁止写入规则区块。
- 不安装依赖，不运行未经批准的项目脚本，不联网或连接生产环境，不触发真实外部动作，不创建提交，不推送，不发布。
- 路径异常、规则冲突或需要扩大权限时立即停止并说明，不得自行绕过。

## 步骤

1. 路径预检：确认 `Test-Path .\VERSION` 和 `Test-Path .\scripts\Install-AICodingRule.ps1` 都返回 `True`；运行 `Resolve-Path "{{PROJECT_RELATIVE_PATH}}"`，逐字输出解析后的目标路径。若路径未替换、解析失败、指向当前基线仓库或目标身份不明确，立即停止。
2. 检查目标工作区：运行 `git -C "{{PROJECT_RELATIVE_PATH}}" status --short`；已有改动只记录，不得覆盖、暂存或清理。
3. 先审计：运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Audit-AICodingRule.ps1 -ProjectPath "{{PROJECT_RELATIVE_PATH}}"`，列出已有和缺失的规则文件。旧项目再运行 Compare，并把 `CUSTOM`、`DRIFT` 或冲突交给用户裁决。
4. 探索项目事实：按 `core/01_READING_RULES.md` 的项目级阅读要求，确认项目类型、组件与端口、环境边界、数据库、鉴权和高风险区域。禁止无目的遍历业务代码。
5. 只做安装预演：运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath "{{PROJECT_RELATIVE_PATH}}" -WhatIf`，输出安装器解析后的基线和项目路径，以及计划创建、跳过和更新的内容。
6. **预演后立即停止。只有用户在后续消息中明确回复“确认安装”，才能继续以下写入步骤。AI 自己审阅计划不等于用户确认。**
7. 收到明确确认后，运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath "{{PROJECT_RELATIVE_PATH}}" -Backup`。`-Backup` 只备份需要更新的既有 `.aicoding-rule.json`，不是项目全量备份。
8. 填写项目层：`05_PROJECT_CONTEXT.md` 的 14 节、入口文件的硬约束/安全底线/高风险追加区、需要启用的 adapters（登记进 `.aicoding-rule.json`）。既有规则文件仍禁止直接覆盖。
9. 一致性检查：CLAUDE.md 与 AGENTS.md 语义一致；README 导航路径有效；运行 `git -C "{{PROJECT_RELATIVE_PATH}}" diff --check`，并检查目标项目实际 diff。
10. 输出报告：解析后的目标路径、安装了什么、跳过了什么、项目层填了什么、测试或检查结果、待人工确认什么。不得自行提交、推送或发布。

## 完成标准

- 项目拥有自包含规则入口（不依赖跨目录读取基线）。
- 项目事实与通用规则分层清晰。
- 未覆盖任何既有文件。
