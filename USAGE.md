# AICoding-RULE 完整使用指南

> 适用版本：0.2.0+。
>
> 本指南面向第一次使用 AI 编码规则的新手，默认环境为 Windows PowerShell。
> 项目设计与目录职责见 `README.md`，版本变化见 `CHANGELOG.md`。

---

## 1. 先理解：它是什么

AICoding-RULE 不是代码生成器，也不是自动发布工具。它是一套可以安装到其他项目中的 AI 协作规则，目的是让 Codex、Claude Code 等 AI 编码工具按稳定流程工作：

```text
理解需求
→ 阅读项目
→ 找到真实调用链
→ 分析影响和风险
→ 提出最小方案
→ 必要时等待确认
→ 修改代码
→ 执行验证
→ 汇报结果和剩余风险
```

它主要解决以下问题：

- AI 没读项目就开始写代码；
- 只修复表面现象，没有找到共用根因；
- 擅自修改数据库、权限、部署或生产配置；
- 没有实际测试却声称已经完成；
- 项目规则散落、互相冲突或长期不更新；
- 同一个 AI 同时施工、验收和批准高风险变更，缺少独立复核。

安装完成后，目标项目会获得自己的规则副本，因此日常使用不依赖本基线仓库持续在线。

---

## 2. 两条必须遵守的红线

### 2.1 不要手改受控区块

以下标记之间的内容由安装脚本从 `core/` 注入：

```text
<!-- AICODING-RULE:BEGIN ... -->
...
<!-- AICODING-RULE:END -->
```

手工修改会被比较脚本报告为 `DRIFT`。项目自己的补充要求应写在文件的“项目扩展规则”区域。

### 2.2 不要把项目事实写进通用规则

项目名称、端口、数据库、部署命令、权限模型和当前风险等事实，应写入：

```text
docs/ai/05_PROJECT_CONTEXT.md
```

通用规则只描述“AI 应该怎样工作”，不保存某个业务项目的当前状态。

---

## 3. 使用前准备

开始前确认：

1. 已安装 Git；
2. 可以打开 Windows PowerShell；
3. 已知道目标项目相对于本仓库根目录的位置；
4. 目标项目最好已经是 Git 仓库；
5. 安装前没有未确认的重要文件改动。

本指南不绑定任何盘符。除非章节另有说明，所有命令都从 AICoding-RULE 基线仓库根目录执行，目标项目示例统一写成：

```text
目标项目：..\你的项目
```

`..\你的项目` 表示目标项目与本仓库位于同一个父目录。目标项目位于其他位置时，请改成从本仓库根目录出发的实际相对路径，并始终用双引号包裹路径。

先确认当前目录确实是基线仓库根目录，并显示目标项目解析后的路径：

```powershell
Test-Path .\VERSION
Test-Path .\scripts\Install-AICodingRule.ps1
Resolve-Path "..\你的项目"
```

前两条命令都应返回 `True`。请逐字核对 `Resolve-Path` 输出，确认它指向预期目标项目，而不是本基线仓库或其他同名目录；任一结果异常都应停止。

确认脚本存在：

```powershell
Get-ChildItem .\scripts
```

应能看到：

```text
Install-AICodingRule.ps1
Audit-AICodingRule.ps1
Compare-ProjectRules.ps1
```

---

## 4. 五分钟快速体验

如果只是想先看看安装器准备做什么，请运行预演：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install-AICodingRule.ps1 `
  -ProjectPath "..\你的项目" `
  -WhatIf
```

`-WhatIf` 表示只显示计划，不写入文件。输出中通常会出现：

```text
创建：CLAUDE.md
创建：AGENTS.md
创建：docs\ai\...
```

如果文件已经存在，会显示：

```text
跳过（已存在，禁止覆盖）
```

这不是错误，而是安装器的安全设计。

---

## 5. 新项目首次接入

这里的“新项目”是指尚未维护 `CLAUDE.md`、`AGENTS.md` 或 `docs/ai/` 规则体系的项目。

### 5.1 先检查工作区

仍在基线仓库根目录运行：

```powershell
git -C "..\你的项目" status --short
```

如果看到已有改动，先确认它们属于谁、是否需要保存。安装器不会覆盖规则文件，但养成安装前检查工作区的习惯可以避免混淆。

### 5.2 预演安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install-AICodingRule.ps1 `
  -ProjectPath "..\你的项目" `
  -WhatIf
```

检查安装器输出的基线与项目解析路径，以及计划创建、跳过和更新的内容。`-WhatIf` 运行后目标项目不应出现新增或改写文件；确认无误后再进入正式安装。

### 5.3 正式安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install-AICodingRule.ps1 `
  -ProjectPath "..\你的项目" `
  -Backup
```

`-Backup` 只在安装器需要更新既有 `.aicoding-rule.json` 时备份该档案，不是项目全量备份。旧项目应先使用 Git 提交或自行建立独立备份。

安装器只创建缺失文件，不覆盖已有规则。通常会生成：

```text
CLAUDE.md
AGENTS.md
.aicoding-rule.json
docs/ai/README.md
docs/ai/01_READING_RULES.md
docs/ai/02_EXECUTION_RULES.md
docs/ai/03_TESTING_RULES.md
docs/ai/04_OUTPUT_RULES.md
docs/ai/05_PROJECT_CONTEXT.md
docs/ai/05_DOCUMENT_GOVERNANCE_RULES.md
```

### 5.4 检查安装结果

```powershell
git -C "..\你的项目" status --short
```

再运行静态审计：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Audit-AICodingRule.ps1 `
  -ProjectPath "..\你的项目"
```

### 5.5 填写项目占位符

安装后的 `{{...}}` 不是错误，而是等待填写的项目事实。重点填写：

| 文件 | 必须填写的内容 |
|---|---|
| `docs/ai/05_PROJECT_CONTEXT.md` | 项目目标、组件、端口、部署、数据库、鉴权、业务流程、风险、测试命令 |
| `CLAUDE.md` | 项目硬约束、安全底线、系统边界、高风险提醒 |
| `AGENTS.md` | 与 `CLAUDE.md` 保持语义一致的约束 |
| `docs/ai/README.md` | 项目专题文档、常用入口和归档入口 |

不要凭印象填写。应让 AI 读取当前代码、配置、迁移、测试和部署文件后再写入。

### 5.6 建议的首次项目接入指令

安装完成后，在目标项目中打开 AI 编码工具，把下面指令完整发送给它：

```text
请执行本项目的首次 AI 规则接入整理。

工作边界：
1. 先阅读 CLAUDE.md 或 AGENTS.md，以及 docs/ai 下规定的必读文件；
2. 只根据当前代码、配置、迁移、测试和运行脚本确认事实，不凭目录名猜测；
3. 找出并填写所有 {{...}} 项目占位符；
4. CLAUDE.md 与 AGENTS.md 的硬约束必须保持语义一致；
5. 项目事实写入 docs/ai/05_PROJECT_CONTEXT.md，不写进受控规则区块；
6. 不修改业务代码，不安装依赖，不运行真实外部动作，不连接生产环境；
7. 修改前先汇报项目理解、证据、风险和计划；
8. 修改后检查残留占位符、文档链接、双入口一致性和 Git diff；
9. 最终列出已确认事实、仍不确定的信息、修改文件和建议人工核对项。
```

仓库还提供了更完整的接入提示词：

```text
prompts/project-bootstrap.md
```

### 5.7 独立提交规则文件

确认内容正确后，建议把规则接入作为独立提交，不与业务功能混在一起：

```powershell
git -C "..\你的项目" add CLAUDE.md AGENTS.md .aicoding-rule.json docs/ai
git -C "..\你的项目" diff --cached --check
git -C "..\你的项目" diff --cached
git -C "..\你的项目" commit -m "文档：接入 AI 编码规则基线"
```

必须在提交前人工检查暂存差异。上述提交命令只是建议，不代表授权 AI 自行提交、推送或发布。

---

## 6. 旧项目安全接入

“旧项目”是指已经存在自己的 AI 规则、项目约束或 `docs/ai/` 文档。原则是先审计、再比较、最后人工裁决，禁止一键替换。

### 6.1 只读审计

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Audit-AICodingRule.ps1 `
  -ProjectPath "..\你的项目"
```

审计会检查入口完整性、双入口漂移、上下文文档膨胀、失效引用和可选工作流完整性等静态问题。

### 6.2 与当前基线比较

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Compare-ProjectRules.ps1 `
  -ProjectPath "..\你的项目"
```

结果解释：

| 状态 | 含义 | 建议处理 |
|---|---|---|
| `MATCH` | 受控区块与当前基线一致 | 无需处理 |
| `MISSING` | 缺少规则文件 | 可运行安装器补齐 |
| `CUSTOM` | 项目使用自有规则 | 人工确认是否已经覆盖基线主题 |
| `DRIFT` | 受控区块被修改或版本落后 | 查看差异并人工裁决，不要自动覆盖 |

查看具体差异：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Compare-ProjectRules.ps1 `
  -ProjectPath "..\你的项目" `
  -ShowDiff
```

### 6.3 建议的旧项目审计指令

```text
请对当前项目执行 AI 规则接入前审计，只读，不修改任何文件。

请完成：
1. 阅读现有 CLAUDE.md、AGENTS.md 和 docs/ai；
2. 区分通用工作规则、项目当前事实、历史过程记录和已失效结论；
3. 检查双入口硬约束是否语义一致；
4. 检查项目事实是否错误地写入通用规则；
5. 检查是否存在相互冲突、重复或失效的要求；
6. 结合当前代码和配置抽查关键事实，不把旧文档直接当作事实；
7. 输出保留项、建议迁移项、建议删除或归档项、与当前基线的冲突项；
8. 给出最小接入方案，但不要执行修改。
```

### 6.4 迁移到受控区块

只有人工确认要采用当前基线时，才按以下步骤处理：

1. 从旧规则中提取项目独有内容；
2. 将项目事实移入 `05_PROJECT_CONTEXT.md`；
3. 备份并改名旧规则文件；
4. 运行安装器生成受控区块版文件；
5. 把合法项目扩展填回受控区块之外；
6. 运行 Compare，确认状态；
7. 人工复核 Git diff 后再删除或归档旧文件。

安装器不会主动覆盖同名文件。

---

## 7. 技术栈适配器

通用规则不会覆盖每种技术栈的细节。项目使用哪些技术，就在 `.aicoding-rule.json` 的 `adapters` 数组登记哪些适配器。

例如，一个 FastAPI、PostgreSQL、Docker Compose 项目可以登记：

```json
"adapters": [
  "python-fastapi",
  "postgresql",
  "docker-compose",
  "windows-powershell"
]
```

当前提供：

| 适配器 | 适用场景 |
|---|---|
| `python-fastapi` | Python、FastAPI、Pydantic、异步接口 |
| `react-typescript` | React、TypeScript、Vite |
| `postgresql` | PostgreSQL 或 SQLite/PostgreSQL 双轨期 |
| `docker-compose` | Docker、Compose、多环境编排 |
| `windows-powershell` | Windows 路径、编码和 PowerShell 脚本 |
| `local-gui-automation` | 本地代理、桌面界面自动化、OCR |

只登记实际使用的适配器。登记后，还应在项目入口规则中说明什么任务需要按需阅读对应文件。

建议指令：

```text
请检查当前项目实际使用的技术栈，并与 .aicoding-rule.json 的 adapters 对照。
只根据依赖文件、构建配置和代码入口确认，不凭 README 猜测。
列出缺失、误登记和建议保留的适配器；未经我确认不要修改档案。
```

---

## 8. 日常 VibeCoding 的正确打开方式

VibeCoding 不等于只说一句“帮我做完”。一个有效指令至少应包含：

```text
目标 + 范围 + 禁止事项 + 验收标准 + 执行权限
```

推荐通用结构：

```text
目标：要解决什么问题。
范围：允许阅读或修改哪些模块。
禁止：明确不能做什么。
验收：什么证据能说明完成。
流程：先阅读和给方案，还是允许直接处理低风险修改。
```

### 8.1 通用开发指令

```text
请按照项目 AI 规则完成以下任务：

目标：<填写目标>
允许范围：<填写模块或目录>
禁止事项：不修改数据库结构、不改变接口协议、不调整部署配置、不引入新依赖，除非先说明并获得确认。
验收标准：<填写可验证结果>

开始时请先：
1. 阅读项目规定的必读文件；
2. 找到真实入口、调用链、数据来源、数据写入点和权限校验点；
3. 搜索相邻实现和所有相关调用方；
4. 区分事实与推测；
5. 给出根因或需求分析、最小修改方案、影响范围、风险等级和验证方案。

低风险且方案明确时可以继续实施；命中数据库、鉴权、权限、部署、生产配置、真实外部动作或删除操作时，先停下等待我确认。
完成后执行与风险相称的验证，并汇报实际命令、结果、未执行项、剩余风险和文档影响。
```

### 8.2 小功能开发指令

```text
请为当前项目增加以下小功能：<功能描述>。

先寻找项目里已经存在的相邻实现、工具函数和依赖，优先复用；不要新增抽象或依赖。
请确认用户入口、后端调用链、数据合同、权限边界和错误处理方式。
修改应限制在实现该功能所需的最少文件内，并补充一个能防止逻辑回退的最小检查。

验收标准：
1. <核心成功场景>；
2. <错误输入或边界场景>；
3. 原有相关流程没有新增失败；
4. 构建或最小测试命令通过。

如果实际需求会改变接口、数据库、权限或部署，请先停止并说明原因。
```

### 8.3 Bug 修复指令

```text
请诊断并修复以下问题：<问题现象和复现步骤>。

不要根据现象直接打补丁。请先：
1. 找到触发入口和完整调用链；
2. 检查相关函数的全部调用方；
3. 用代码、日志或测试证据确认真实根因；
4. 判断根因是否位于共用函数，避免给每个调用方重复加补丁；
5. 给出最小修复方案和不会修改的内容。

确认属于低风险局部修复后可以实施。请留下一个能复现原问题并防止回归的最小测试或自检。
最终报告真实根因、修改文件、验证命令、结果、旧链路影响和剩余风险。
```

### 8.4 只读诊断指令

```text
请只读调查以下问题：<问题描述>。

本轮禁止修改文件、安装依赖、创建提交、连接生产环境或触发真实外部动作。
请读取项目规则，追踪真实调用链，检查相关配置、日志入口、调用方和测试。
输出：已确认事实、证据位置、仍待验证的假设、可能影响范围、风险等级和下一步最小验证建议。
```

### 8.5 代码评审指令

```text
请评审当前工作区相对于基线提交的变更。

重点检查：
1. 是否满足原始需求和验收标准；
2. 是否存在功能错误、权限绕过、数据损坏或兼容性回退；
3. 是否遗漏调用方、异常路径和边界输入；
4. 是否引入不必要的抽象、依赖或范围扩张；
5. 测试是否真正覆盖修改逻辑；
6. 文档中的当前事实是否因本次修改而过期。

只报告有证据的问题，按严重程度排序，并引用文件和位置。若没有发现问题，也要说明尚未验证的范围。
本轮只评审，不修改代码。
```

### 8.6 测试与交付检查指令

```text
请对当前修改执行交付前验证。

先读取需求、验收标准和项目测试规则，然后检查实际 Git diff。
运行与改动风险相称的最小测试、相关回归、构建或静态检查。
不得用“理论上正确”代替执行证据，也不得把环境阻塞写成通过。

输出：
1. 实际执行的每条命令和结果；
2. 未执行的测试及原因；
3. 原问题或核心场景是否得到验证；
4. Git 工作区是否包含无关文件、密钥或构建产物；
5. 剩余风险和建议人工验证项；
6. 是否具备提交条件，但不要自行推送或发布。
```

### 8.7 文档维护指令

```text
请检查本轮代码或配置变化是否让项目文档中的当前事实过期。

先以当前代码、配置、迁移和测试结果为证据，再更新文档。
失效结论必须原位替换或删除，禁止追加“最新说明”后继续保留旧错误结论。
只修改受影响的文档，不把任务流水账写入 05_PROJECT_CONTEXT.md。
最终说明修改了哪些文档；如无影响，明确写“无文档影响”。
```

---

## 9. 风险分级与工作流选择

三权分离按风险启用，不按文件数量或代码行数启用。

| 等级 | 常见任务 | 建议流程 |
|---|---|---|
| L0 | 文档、文案、注释、格式，不改变运行语义 | 单窗口 + 最小验证 |
| L1 | 局部页面、普通 CRUD、小范围 Bug、非敏感配置 | 单窗口加强审查、双窗口或轻量三窗口 |
| L2 | 跨模块、前后端联动、多服务合同、数据写入、大范围重构 | 推荐完整三权分离 |
| L3 | 鉴权、权限、租户隔离、数据库迁移、数据删除、支付、真实发送、生产配置和发布 | 必须完整三权分离，生产发布需要人工负责人批准 |

命中多个等级时取最高等级。环境无法验证时不得降低风险等级或宣称通过。

---

## 10. 三权分离完整实操

三权分离把高风险任务拆成三个独立上下文：

| 窗口 | 负责 | 不负责 |
|---|---|---|
| 审批窗口 | 冻结需求、风险分级、执行包、候选审查、测试请求、最终裁决 | 不修改业务代码，不代替测试 |
| 执行窗口 | 按执行包施工、自测、创建本地候选提交 | 不改变需求，不自行批准或推送 |
| 测试窗口 | 对指定候选提交进行隔离、独立验收 | 不修改业务代码，不替执行窗口修复 |

三份角色 Prompt 可以由相同模型执行，但必须使用彼此隔离的对话上下文和工作树。不能在同一个聊天里依次声称自己是三个独立角色。

### 10.1 安装可选模块

先预演：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install-AICodingRule.ps1 `
  -ProjectPath "..\你的项目" `
  -IncludeThreeAuthorityWorkflow `
  -WhatIf
```

确认后安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install-AICodingRule.ps1 `
  -ProjectPath "..\你的项目" `
  -IncludeThreeAuthorityWorkflow `
  -Backup
```

模块会复制到：

```text
docs/ai/workflows/three-authority-vibecoding/
docs/ai/prompts/three-authority-vibecoding/
docs/ai/templates/three-authority-vibecoding/
```

安装不等于启用。每个任务仍需先判定风险并记录启用理由。

安装后，以下入口均相对于目标项目根目录：先阅读 `docs/ai/workflows/three-authority-vibecoding/README.md`，再把 `docs/ai/prompts/three-authority-vibecoding/approver-window.md` 交给审批会话，由审批窗口生成执行和测试指令。

### 10.2 推荐的窗口准备方式

新手可以打开三个独立 AI 会话：

```text
会话 A：审批窗口
会话 B：执行窗口
会话 C：测试窗口
```

同时使用三个隔离工作树：

```text
审批工作树：只读审查
执行工作树：功能分支，可写
测试工作树：检出指定候选提交，只测试
```

三个窗口不得共享同一个可写工作区，也不得同时在主分支施工。

### 10.3 发给审批窗口的启动指令

```text
请启用 Three-Authority VibeCoding Governance，并担任审批窗口。

任务：<填写任务>
业务目标：<填写目标>
已知限制：<填写限制，没有则写 NONE>

请先阅读项目规则、三权分离工作流入口、启用规则、状态机、交接契约和审批窗口 Prompt。
本窗口只负责探索、需求冻结、风险分级、范围裁决、验收矩阵和后续审批，不修改业务代码。

请先输出 PLAN_DRAFT，至少包含：
- Task-ID；
- Plan-Revision；
- Base-Commit；
- Risk-Level；
- Workflow-Mode；
- Activation-Reasons；
- Owner-Constraints；
- 允许和禁止范围；
- 调用链、数据合同和权限边界；
- 可执行的验收矩阵；
- 残余风险。

信息不足时继续只读探索，不得编造。计划完整后生成正式 EXECUTION_WINDOW_INSTRUCTION，但不要替执行窗口施工。
```

审批窗口应记录：

```text
Risk-Level:
Workflow-Mode: single / dual / light-three-authority / full-three-authority
Activation-Reasons:
Owner-Constraints:
```

### 10.4 发给执行窗口的指令

审批窗口批准计划后，会生成 `EXECUTION_WINDOW_INSTRUCTION`。将完整内容原样交给独立执行窗口：

```text
请担任 Three-Authority VibeCoding 的执行窗口。

先阅读项目规则、执行窗口 Prompt、状态机和交接契约，然后严格执行下方正式执行包：

<粘贴审批窗口生成的完整 EXECUTION_WINDOW_INSTRUCTION>

执行边界：
1. 不改变需求、范围、验收标准、Base-Commit 或权限边界；
2. Allowed-Files 不足、基线漂移或计划冲突时停止并请求 REPLAN；
3. 只选择性暂存本任务文件，不夹带工作区原有改动；
4. 完成施工和自测后创建本地候选提交；
5. 不推送、不合并、不发布；
6. 使用 execution-report 模板返回完整 Candidate-Commit、实际差异、测试证据、Git 状态和残余风险。
```

执行完成后的关键状态是：

```text
CANDIDATE_READY <完整提交哈希>
```

分支名、标签、`HEAD` 和缩写哈希都不能代替完整提交哈希。

### 10.5 审批窗口审查候选

把执行报告完整交回审批窗口：

```text
请继续担任审批窗口，审查以下 CANDIDATE_READY 执行报告：

<粘贴完整 execution-report>

请核验 Base-Commit 与 Candidate-Commit、祖先关系、提交历史、实际 diff、Allowed-Files、验收矩阵、自测证据和残余风险。
候选不符合计划时输出 `R1 <full-candidate-hash>`、`R2 <full-candidate-hash>`、`REPLAN <full-candidate-hash>` 或 `REJECT_SCOPE <full-candidate-hash>`；符合时输出 `APPROVE_TEST <full-candidate-hash>`，并生成绑定同一完整 Candidate-Commit 的 TEST_WINDOW_INSTRUCTION。
不要修改代码，不要代替测试窗口宣布通过。
```

### 10.6 发给测试窗口的指令

```text
请担任 Three-Authority VibeCoding 的独立测试窗口。

先阅读项目测试规则、测试窗口 Prompt、状态机和交接契约，然后执行下方正式测试请求：

<粘贴审批窗口生成的完整 TEST_WINDOW_INSTRUCTION>

测试前必须确认实际 HEAD 与 Candidate-Commit 逐字符一致，并记录工作区状态。
只测试指定候选，不修改业务代码，不替执行窗口修复，不降低验收标准。
请使用 independent-test-report 模板记录实际命令、结果、未执行项、复现证据、最终 Git 状态和残余风险。
只能根据证据输出 PASS、CONDITIONAL_PASS、FAIL、TEST_BLOCKED 或 SPEC_GAP；环境阻塞不得写成 PASS。
```

### 10.7 返工规则

测试失败后，审批窗口根据情况输出：

- `R1 <full-candidate-hash>`：局部、明确且仍在原计划内的返工；
- `R2 <full-candidate-hash>`：较大但仍未改变冻结目标的返工；
- `REPLAN <full-candidate-hash>`：需求、范围、合同、基线或验收矩阵必须重写；
- `REJECT_SCOPE <full-candidate-hash>`：请求越权或不属于当前任务。

任何代码变化、`amend`、`rebase`、`squash`、`merge`、`cherry-pick` 或冲突修复都会产生新候选哈希。旧审批和测试证据不能转移到新哈希，新候选必须重新进入：

```text
CANDIDATE_READY <new-full-candidate-hash>
→ 候选审查
→ APPROVE_TEST <new-full-candidate-hash>
→ TEST_REQUEST <new-full-candidate-hash>
→ 独立测试同一新候选
```

### 10.8 推送和生产发布

测试通过不等于允许推送。审批窗口还需明确输出：

```text
APPROVE_PUSH <full-candidate-hash>
```

执行窗口只能按批准的远端、分支、预期远端哈希和显式 refspec 推送。工作流禁止强制推送。无论推送命令返回非零或异常，都必须重新读取精确 Push-Ref；若远端实际哈希等于 Candidate-Commit，仍应输出 `PUSHED <full-candidate-hash>`。

若远端实际哈希仍等于 Expected-Remote-Hash 或为其他哈希，执行窗口只回传证据和 REMOTE_DRIFT；结果为 UNKNOWN 时只回传证据和 PUSH_OUTCOME_UNKNOWN，不自行输出 REPLAN。审批窗口核对后输出 `REPLAN <full-candidate-hash>`，旧 APPROVE_PUSH 不得重放或用于重试。

L3 生产发布还必须经过：

```text
OWNER_APPROVAL_REQUIRED <full-candidate-hash>
→ 人工负责人批准同一候选、环境和已测试制品摘要
→ APPROVE_RELEASE <full-candidate-hash>
→ 部署同一已测试制品
→ RELEASED <full-candidate-hash>
```

发布前且尚无部署副作用、Candidate-Commit 未变化时，制品缺失、需要重建或摘要变化由执行窗口只回传 ARTIFACT_INVALIDATED 和证据；审批窗口输出 `TEST_REQUEST <full-candidate-hash>`，旧测试结论、APPROVE_RELEASE 和 Owner-Evidence 失效。

发布开始前，若部署策略、目标环境或其他发布前提变化或失效，执行窗口或获授权发布者只回传证据，由审批窗口输出 `REPLAN <full-candidate-hash>`；旧 APPROVE_RELEASE 和 Owner-Evidence 均失效且不得重放，重新发布前必须重新批准并在适用时取得新的 Owner 证据。

发布已经开始后，已知失败或部分成功使用 RELEASE_PARTIAL，包括 0 个目标成功；结果无法确认时使用 RELEASE_OUTCOME_UNKNOWN。执行窗口只回传每个目标的实际摘要、健康检查、执行步骤和回滚情况，审批窗口输出 `REPLAN <full-candidate-hash>`；旧 APPROVE_RELEASE 和 Owner-Evidence 不得重放。

只有全部目标的实际 Artifact-Digest 都等于批准摘要且健康检查均通过，执行窗口才可输出 RELEASED。批准后重新构建会改变制品证据，必须重新测试和批准。

---

## 11. 日常审计、比较和升级

### 11.1 快速体检

验证基线仓库自身的三权工作流契约：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
```

审计目标项目：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Audit-AICodingRule.ps1 `
  -ProjectPath "..\你的项目"
```

### 11.2 检测基线漂移

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Compare-ProjectRules.ps1 `
  -ProjectPath "..\你的项目"
```

### 11.3 项目规则合法覆盖

项目明确不采用某条基线规则时，在 `.aicoding-rule.json` 的 `overrides` 中登记决定、批准人和日期。登记覆盖不是为了隐藏差异，而是让后续审计知道这是经过批准的项目决策。

### 11.4 基线升级

基线升级后不要直接覆盖项目文件。推荐顺序：

1. 运行 Compare 查看差异；
2. 阅读 `CHANGELOG.md`；
3. 人工判断新规则与项目扩展是否冲突；
4. 备份项目扩展内容；
5. 改名旧受控文件；
6. 运行 Install 重建；
7. 将合法项目扩展填回区块外；
8. 再运行 Compare 和 Audit；
9. 人工检查 Git diff 后独立提交。

---

## 12. 常见问题与排查

### 12.1 安装器为什么不覆盖已有文件

这是安全设计。已有文件可能包含项目特有规则，自动覆盖会造成约束丢失。请使用 Compare 后人工合并。

### 12.2 `CUSTOM` 是不是错误

不是。它表示项目使用自有规则且没有受控区块。需要人工判断其主题是否完整、是否应迁移。

### 12.3 `DRIFT` 应该直接修复吗

不要自动修复。先检查是版本落后、误改受控区块，还是项目已经批准的合法覆盖。

### 12.4 PowerShell 中文乱码或解析错误

确认脚本是 UTF-8 编码。需要时先设置：

```powershell
[Console]::OutputEncoding = [Text.Encoding]::UTF8
```

仓库脚本已针对 PowerShell 编码差异做显式处理。

### 12.5 重复安装会清空 adapters 或 overrides 吗

0.2.0 已修复该问题。安装器会保留合法字段和首次安装时间；没有实际变化时不会重写档案。

### 12.6 安装三权模块后会自动启用吗

不会。安装只是复制文件。每个任务必须根据风险单独决定是否启用。

### 12.7 可以让一个 AI 在同一对话扮演三个角色吗

不可以。三权分离依赖上下文、工作树和证据隔离。同一个模型可以承担不同角色，但必须使用独立会话。

### 12.8 AI 可以自行提交、推送或发布吗

只有用户明确授权且项目规则允许时才能执行。三权流程中的本地候选提交不等于允许推送；测试通过也不等于允许发布。

### 12.9 审计脚本没有报告问题，是否代表项目完全安全

不是。Audit 是静态辅助检查，不能判断所有语义冲突、业务权限或运行风险。复杂审计应结合 `prompts/baseline-rule-audit.md` 和人工复核。

---

## 13. 新手推荐路径

第一次使用，按下面顺序即可：

```text
1. 对目标项目运行 Install -WhatIf
2. 正式运行 Install -Backup
3. 用“首次项目接入指令”让 AI 探索并填写占位符
4. 运行 Audit 和 Compare
5. 人工检查 Git diff
6. 将规则接入独立提交
7. 日常任务使用对应的 VibeCoding 指令
8. L2/L3 任务启用三权分离
9. 每次大阶段结束检查测试、风险和文档影响
```

常用入口速查：

| 目标 | 使用内容 |
|---|---|
| 第一次安装 | `Install-AICodingRule.ps1 -WhatIf`，确认后正式安装 |
| 填写项目事实 | 本文“首次项目接入指令”或 `prompts/project-bootstrap.md` |
| 只读检查规则 | `Audit-AICodingRule.ps1` |
| 比较项目和基线 | `Compare-ProjectRules.ps1` |
| 只读诊断代码 | 本文“只读诊断指令” |
| 开发普通功能 | 本文“通用开发指令”或“小功能开发指令” |
| 修复问题 | 本文“Bug 修复指令” |
| 交付前检查 | 本文“测试与交付检查指令” |
| 高风险开发 | 安装并启用 Three-Authority VibeCoding Governance |

最后记住：规则的价值不在于文档数量，而在于每次任务都能留下可验证、可解释、可追溯的证据。
