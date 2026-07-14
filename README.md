# AICoding-RULE — 可复用 AICoding / VibeCoding 规则基线

> 版本见 `VERSION`；变更见 `CHANGELOG.md`；**新/旧项目接入与日常使用见 `USAGE.md`**。
> 来源：`E:\work` 下多个真实项目（含线索分发、AI 客服、剪辑工具、二手车系统）多轮实践验证的规则资产整理，
> 不是从零设计的新规则体系。来源盘点见 `reports/rule-source-inventory.md`，冲突裁决见 `reports/rule-conflict-report.md`。

## 设计原则

1. **通用规则与项目事实分离**：core 只回答"怎么工作"；项目是什么/现状/风险写在各项目的 05_PROJECT_CONTEXT.md 与入口文件项目区。项目事实禁止进入 core。
2. **单一来源 + 项目自包含**：core 是唯一规则来源；安装时把 core 内容注入项目规则文件的**受控区块**（managed block），项目文件自包含、可独立被任何 AI 工具读取，不依赖跨目录引用。漂移由版本标记 + Compare 脚本检测。
3. **默认不覆盖**：安装脚本只创建缺失文件；已有规则文件一律跳过并提示用 Compare 对比后人工合并。
4. **规则也防膨胀**：治理规则（core/05）约束 05 上下文防流水账、归档默认不读、原位替换旧结论、治理层高修改门槛。

## 目录职责

```text
core/                  通用核心规则（单一来源）
  01_READING_RULES.md            怎么读项目
  02_EXECUTION_RULES.md          怎么改代码（含阶段总控/懒惰阶梯/Bug根因门/高风险日志）
  03_TESTING_RULES.md            怎么验证（含最小有效验证/环境性失败基线）
  04_OUTPUT_RULES.md             怎么汇报（含完成报告11项）
  05_DOCUMENT_GOVERNANCE_RULES.md 文档治理与自治维护
entry-templates/       CLAUDE.md / AGENTS.md 入口模板（等效双入口，含 {{项目占位区}}）
project-templates/     docs/ai 项目文件模板（受控区块 + 项目扩展区；05 为十四节事实文档模板）
adapters/              技术栈适配规则，项目按需启用（python-fastapi / react-typescript /
                       postgresql / docker-compose / windows-powershell / local-gui-automation）
prompts/               标准任务提示词（接入 / 规则审计 / 文档基线重构 / 周期维护 / 只读审计）
scripts/               Install（安装，-WhatIf/-Backup）/ Audit（静态审计）/ Compare（基线比较）
schemas/               .aicoding-rule.json 项目档案示例（版本/启用的 adapters/合法覆盖登记）
reports/               来源清单、冲突报告、维护报告模板
archive/               基线自身的历史归档区
```

## 快速使用

```powershell
# 1. 只读审计一个项目
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Audit-AICodingRule.ps1 -ProjectPath E:\work\project\demo

# 2. 预演安装（不写任何文件）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -WhatIf

# 3. 正式安装（只创建缺失文件）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -Backup

# 4. 与基线比较（检测漂移 / 自有规则 / 缺失）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compare-ProjectRules.ps1 -ProjectPath E:\work\project\demo
```

新项目完整接入流程见 `prompts/project-bootstrap.md`。

## 升级机制

1. 修改 core → 更新 `VERSION` 与 `CHANGELOG.md`（治理层修改须满足 core/05 #8 门槛）。
2. 项目侧运行 Compare 查看差异 → 人工确认后用 Install 重注受控区块（区块外扩展区不受影响）。
3. Audit 脚本会报告"区块版本落后于基线"。

## 边界声明

- 静态脚本只做辅助检查，不声称能判断全部语义冲突；语义级审计用 prompts/ 下的任务提示词。
- 本仓库不包含任何具体项目的业务事实；项目示例仅出现在报告与注释中作为来源说明。
- 已有成熟规则的项目（无受控区块）视为"合法覆盖候选"，Compare 报 CUSTOM，是否接入由开发者裁决。
