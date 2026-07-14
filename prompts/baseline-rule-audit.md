# Prompt: 规则基线审计（baseline-rule-audit）

> 用途：审计某项目的规则体系与 AICoding-RULE 基线的偏差。只读任务。

------

## 任务

审计项目 `{{PROJECT_PATH}}` 的 AI 规则体系（基线：`{{BASELINE_PATH}}`，版本见 VERSION）。

## 边界

只读。不修改任何文件；发现的问题输出为报告和建议 diff。

## 检查项

1. 入口完整性：CLAUDE.md / AGENTS.md / docs/ai 01~05 是否齐全。
2. 双入口漂移：CLAUDE.md 与 AGENTS.md 硬约束是否语义一致（列出差异行）。
3. 受控区块：区块版本是否落后于基线 VERSION；区块内是否被手改（与 core 内容对比）。
4. 规则/事实分层：规则文件（01~04）中是否泄漏项目事实（端口、路径、命令、人名/联系人、具体环境变量值）；应迁移到 05 或扩展区的内容清单。
5. 文档腐化信号：
   - 追加式旧结论（"最新补充""以最新内容为准"）；
   - "已完成"与"进行中"并存的同一主题；
   - 05_PROJECT_CONTEXT.md 是否膨胀为流水账（体量、按日期追加的章节）。
6. 归档纪律：归档文件是否混入"当前常用入口"；归档头部是否有"非当前事实"声明。
7. 引用有效性：README / 入口文件引用的路径是否存在。

## 输出

- 按检查项给出：结论 + 证据（文件:行）+ 建议处理（KEEP/REWRITE/MERGE/PARAMETERIZE/ARCHIVE/DELETE）。
- 无法自动裁决的冲突单独列"人工确认清单"。
- 辅助工具：`Audit-AICodingRule.ps1`、`Compare-ProjectRules.ps1`（静态检查仅作辅助，语义判断以人工阅读为准）。
