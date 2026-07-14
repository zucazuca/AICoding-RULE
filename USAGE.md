# AICoding-RULE 使用指南

> 适用版本：0.1.0+。本指南回答"拿到这个规则库后怎么用"，分**新项目**与**旧项目**两种情形。
> 设计背景与目录职责见 `README.md`；来源与裁决见 `reports/`。

------

## 0. 两条红线（先记住）

1. **受控区块内永远不手改**：`<!-- AICODING-RULE:BEGIN ... -->` 与 `END` 之间的内容由安装脚本注入，升级靠 Install 重注，手改会被 Compare 报 DRIFT。
2. **项目事实永远不写进规则区块**：项目是什么、端口、命令、门禁现状等写 `docs/ai/05_PROJECT_CONTEXT.md` 和各规则文件的"项目扩展规则"区。

------

## 1. 情形一：新项目（或还没有任何 AI 规则的项目）

### 步骤 1：预演安装（不写任何文件）

```powershell
cd E:\work\AICoding-RULE
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath <项目路径> -WhatIf
```

### 步骤 2：正式安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-AICodingRule.ps1 -ProjectPath <项目路径>
```

只创建缺失文件：`CLAUDE.md`、`AGENTS.md`、`docs/ai/`（README + 01~04 受控区块规则 + 05 上下文模板 + 05 治理规则）、`.aicoding-rule.json` 版本标记。

### 步骤 3：填项目层占位符（关键步骤）

装完的文件里**规则已就绪，但 `{{...}}` 是空的**：

| 文件 | 要填什么 |
|---|---|
| `docs/ai/05_PROJECT_CONTEXT.md` | 十四节项目事实：项目是什么、组件与端口、环境与部署、数据库、鉴权与隔离、安全门禁、已完成/未完成、风险与注意事项、推荐入口 |
| `CLAUDE.md` / `AGENTS.md` | 硬约束区、项目定位与边界、安全底线区、高风险追加区、Critical Reminders 项目条目（**两份必须语义一致**） |
| `docs/ai/README.md` | 专题目录、常用入口、归档入口 |
| 可选块 | 不适用的直接删（如非中文团队删"项目语言规范"块） |

**最省事的方式**：把 `prompts/project-bootstrap.md` 整篇复制给 AI 执行窗口，替换 `{{PROJECT_PATH}}` 和 `{{BASELINE_PATH}}`，让 AI 自己探索项目、填写事实、跑一致性检查。

### 步骤 4：启用技术栈适配器

在 `.aicoding-rule.json` 的 `adapters` 数组登记项目用到的技术栈：

```json
"adapters": ["python-fastapi", "postgresql", "docker-compose"]
```

并在任务中要求 AI 按需阅读对应的 `adapters/<name>/RULES.md`（可在项目 CLAUDE.md 的必读顺序后追加一行说明）。

### 步骤 5：独立提交

项目里新增的规则文件单独 commit 一次，不与业务代码混提交。

------

## 2. 情形二：旧项目（已有自己的 CLAUDE.md / docs/ai 规则）

**原则：脚本永远不会覆盖已有规则文件**。接入是"先对比、人工裁决、逐步靠拢"，不是一键替换。

### 步骤 1：只读体检

```powershell
cd E:\work\AICoding-RULE
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Audit-AICodingRule.ps1 -ProjectPath <项目路径>
```

检查：入口完整性、CLAUDE/AGENTS 漂移、05 膨胀与流水账化、追加式旧结论、归档混入常用入口、失效引用。

### 步骤 2：与基线对比

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compare-ProjectRules.ps1 -ProjectPath <项目路径>
```

### 步骤 3：按 Compare 结果分类处理

| 状态 | 含义 | 处理 |
|---|---|---|
| `MISSING` | 项目缺该规则文件 | 直接跑 Install，只会补缺失的这几个，其余全部跳过 |
| `CUSTOM` + 疑似缺少基线主题 | 项目自有规则落后于基线 | 二选一：**保守**——手工把缺的章节抄进项目规则（保留自有结构）；**彻底**——见下方"迁移到受控区块" |
| `CUSTOM` 且主题齐全 | 项目自有成熟规则 | 可以不动；差异属措辞级，人工抽查 |
| `DRIFT` | 受控区块被手改或版本落后 | 查 `.aicoding-rule.json` 的 overrides：登记过 → 合法覆盖；没登记 → 决定恢复区块（Install 重注）或补登记 |

**项目确实不想要某条基线规则** → 在 `.aicoding-rule.json` 的 `overrides` 登记（规则、决定、批准人、日期），下次 Compare/审阅先查这里。

### 迁移到受控区块（"彻底"路线）

1. 把项目规则文件中的**项目独有内容**先挪到 05_PROJECT_CONTEXT.md 或独立记录；
2. 旧规则文件改名备份（如 `01_READING_RULES.md.legacy`），因为 Install 不覆盖同名文件；
3. 跑 Install 生成受控区块版文件；
4. 把第 1 步的项目独有内容填回各文件的"项目扩展规则"区；
5. Compare 确认 MATCH，删除或归档 `.legacy` 备份，独立 commit。

### 步骤 4（可选）：文档已腐化的旧项目先做基线重构

05 已成流水账、结论互相矛盾的项目，先复制 `prompts/baseline-doc-refactor.md` 给 AI 执行一次基线重构（先探索事实 → 分类 → 归档 → 重写 05 → 一致性检查），再走上面的接入流程。

------

## 3. 日常使用速查

| 你要做什么 | 用什么 |
|---|---|
| 快速体检一个项目 | `Audit-AICodingRule.ps1`（只读） |
| 看项目规则和基线差多少 | `Compare-ProjectRules.ps1`（只读；加 `-ShowDiff` 看差异行） |
| 补缺失文件 / 首次接入 | `Install-AICodingRule.ps1`（先 `-WhatIf`；改 profile 前可加 `-Backup`） |
| 项目事实变了 | 只改项目的 `05_PROJECT_CONTEXT.md`，不动规则区块 |
| 想改通用规则本身 | 改 `core/`，升 `VERSION` + 记 `CHANGELOG`（须满足 core/05 #8 治理层门槛），各项目 Compare 后重注区块 |
| 每个大阶段收口 | 复制 `prompts/periodic-maintenance.md` 给 AI 执行 |
| 不确定项目状态、怕误改 | 复制 `prompts/audit-only.md` 给 AI（严格只读） |

## 4. 升级流程（基线出新版本后）

```powershell
# 项目侧：
# 1. 看差异
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compare-ProjectRules.ps1 -ProjectPath <项目路径>
# 2. 人工确认无冲突后，重注区块：备份旧规则文件改名 → Install 重建 → 扩展区内容填回
# （Audit 会持续报告"区块版本落后于基线"直到升级完成）
```

扩展区内容在区块外，重注区块不影响它；但仍建议升级后 diff 复核一遍。

## 5. 常见问题

- **PowerShell 报解析错误 / 中文乱码**：确认脚本文件是 UTF-8 **带 BOM**（仓库内已是）；控制台输出乱码可加 `[Console]::OutputEncoding=[Text.Encoding]::UTF8` 前缀执行。
- **Compare 报"疑似缺少基线主题"但项目其实有**：该检查是标题级启发式（措辞不同、标题在代码块内都会误计），属"疑似"提示，以人工阅读为准。
- **Install 想覆盖某个已存在文件**：不支持，这是有意设计。改名备份旧文件后再装，或手工合并。
- **AI 工具读哪个入口**：Claude Code 读 CLAUDE.md，其他工具读 AGENTS.md；两者等效，改约束必须同步。
