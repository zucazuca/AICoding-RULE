# 维护报告模板（maintenance-report.template）

> 用途：prompts/periodic-maintenance.md 任务的产出格式。

# {{PROJECT_NAME}} 规则与上下文维护报告（{{DATE}}）

## 1. 审计摘要

- 基线版本：项目 {{PROJECT_BLOCK_VERSION}} / 基线 {{BASELINE_VERSION}}
- Audit-AICodingRule.ps1 发现：{{条数与级别}}
- Compare-ProjectRules.ps1 结果：{{MATCH/DRIFT/CUSTOM/MISSING 概览}}

## 2. 事实抽查结果

| 05 中的结论 | 核验证据 | 结论 |
|---|---|---|
| {{...}} | {{文件:行 / 配置 / 迁移}} | 成立 / 已过期（已原位替换） |

## 3. 本轮文档修改

- 修改文件与原因：
- 替换 / 删除的旧结论：
- 归档内容：

## 4. 升级动作

- 受控区块升级：是 / 否（{{版本 → 版本}}）
- 项目扩展区受影响：是 / 否

## 5. 一致性检查

- 双入口一致性：
- 引用路径有效性：
- git diff --check：

## 6. 遗留与人工确认

- {{无法自动裁决事项}}

## 7. 结论

- 无文档影响的部分：
- commit：{{hash / 建议信息}}
