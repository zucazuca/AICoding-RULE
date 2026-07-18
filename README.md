# AICoding-RULE — 可复用 AICoding / VibeCoding 规则基线

> 版本见 `VERSION`；变更见 `CHANGELOG.md`；**新/旧项目接入与日常使用见 `USAGE.md`**。
> 来源：多个真实项目（含线索分发、AI 客服、剪辑工具、二手车系统）多轮实践验证的规则资产整理，
> 不是从零设计的新规则体系。来源盘点见 `reports/rule-source-inventory.md`，冲突裁决见 `reports/rule-conflict-report.md`。

## 设计原则

1. **通用规则与项目事实分离**：core 只回答"怎么工作"；项目是什么/现状/风险写在各项目的 05_PROJECT_CONTEXT.md 与入口文件项目区。项目事实禁止进入 core。
2. **单一来源 + 项目自包含**：core 是默认通用规则的唯一来源；可选高级工作流在各自模块内保持单一事实源。安装时把所选内容复制进项目，项目文件自包含、可独立被任何 AI 工具读取，不依赖跨目录引用。core 漂移由版本标记 + Compare 脚本检测。
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
workflows/              可选高级治理工作流（默认关闭，不进入 Required Reading）
prompts/               按需任务与角色提示词（索引见 prompts/README.md）
templates/             可复制的结构化交接模板（索引见 templates/README.md）
scripts/               Install（安装，-WhatIf/-Backup）/ Audit（静态审计）/ Compare（基线比较）
schemas/               .aicoding-rule.json 项目档案示例（版本/启用的 adapters/合法覆盖登记）
reports/               来源清单、冲突报告、维护报告模板
archive/               基线自身的历史归档区
```

## 可选高级治理工作流

对于中高风险任务，应避免由同一 AI 上下文同时完成方案制定、代码施工、独立验收和最终批准。

项目可根据风险选择审批、执行和测试角色分离。该模式不是低风险任务的默认强制流程，默认不启用，也不会把三个长 Prompt 加入 Required Reading。

完整规范参见 [Three-Authority VibeCoding Governance](workflows/three-authority-vibecoding/README.md)。

## 快速使用

以下命令均从 AICoding-RULE 基线仓库根目录执行，示例目标项目 `"..\你的项目"` 是相对于当前目录的路径。正式写入前先核对安装器输出的基线与项目解析路径；完整的新手流程和异常处理见 `USAGE.md`。

```powershell
# 1. 只读审计一个项目
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Audit-AICodingRule.ps1 -ProjectPath "..\你的项目"

# 2. 预演安装（不写任何文件）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath "..\你的项目" -WhatIf

# 3. 人工确认预演计划后正式安装（只创建缺失文件）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath "..\你的项目" -Backup

# 4. 与基线比较（检测漂移 / 自有规则 / 缺失）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compare-ProjectRules.ps1 -ProjectPath "..\你的项目"

# 5. 可选：预演三权分离模块安装（复制不等于启用）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath "..\你的项目" -IncludeThreeAuthorityWorkflow -WhatIf
```

`-Backup` 只备份需要更新的既有 `.aicoding-rule.json`，不是项目全量备份。新手先阅读 `USAGE.md`；理解路径、预演和人工确认边界后，再把 `prompts/project-bootstrap.md` 作为接入指令交给 AI。

## 升级机制

1. 修改 core → 更新 `VERSION` 与 `CHANGELOG.md`（治理层修改须满足 core/05 #8 门槛）。
2. 项目侧运行 Compare 查看差异 → 人工确认后备份并移走待升级的旧受控文件，再用 Install 重建（区块外扩展规则须人工合回）。
3. Audit 脚本会报告"区块版本落后于基线"。

## 边界声明

- 静态脚本只做辅助检查，不声称能判断全部语义冲突；语义级审计用 prompts/ 下的任务提示词。
- 本仓库不包含任何具体项目的业务事实；项目示例仅出现在报告与注释中作为来源说明。
- 已有成熟规则的项目（无受控区块）视为"合法覆盖候选"，Compare 报 CUSTOM，是否接入由开发者裁决。
