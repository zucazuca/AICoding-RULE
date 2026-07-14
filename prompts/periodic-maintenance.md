# Prompt: 周期维护（periodic-maintenance）

> 用途：按周期（建议每个大阶段收口或每 2~4 周）对项目规则与上下文做例行维护。

------

## 任务

对项目 `{{PROJECT_PATH}}` 执行 AI 文档周期维护。

## 步骤

1. 运行审计：`Audit-AICodingRule.ps1 -ProjectPath {{PROJECT_PATH}}` + 按 prompts/baseline-rule-audit.md 人工复核。
2. 事实抽查：从 05_PROJECT_CONTEXT.md 抽取 5~10 条关键结论，反向核验代码/配置/迁移是否仍然成立；不成立的原位替换。
3. 膨胀检查：05 体量与结构（是否出现按日期追加）；规则文件是否沉积任务期章节。
4. 归档动作：把已完成阶段的详细过程移入 archive/（带冻结声明头），活动文档留一句必要提醒。
5. 冲突扫描：状态并存（已完成+进行中）、双入口漂移、失效引用。
6. 升级检查：受控区块版本是否落后基线；如落后，用 Install 脚本升级并复核项目扩展区未受影响。
7. 输出维护报告（用 reports/maintenance-report.template.md），独立 docs commit。

## 边界

- 不修改业务代码；文档修改独立提交。
- 无法自动裁决的业务结论列入人工确认清单，不擅自选择。
