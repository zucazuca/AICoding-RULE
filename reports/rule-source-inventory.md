# 规则来源清单（rule-source-inventory）

> 生成时间：2026-07-14（P0-AICODING-RULE-REUSABLE-BASELINE-1）
> 说明：本清单是建立 0.1.0 基线时的规则资产盘点结果。权威性按"规则事实优先级"判断，不以文件修改时间为唯一依据。

## 已采用来源

| 文件路径 | 所属 | 职责 | 最近修改 | 使用状态 | 通用程度 | 可信度 | 冲突 | 处理 |
|---|---|---|---|---|---|---|---|---|
| `E:\work\project\docs\ai\01~04_*.md` | 通用目录（project 根） | 阅读/执行/测试/输出规范 | 2026-06-05 | 活跃（作为拷贝源） | 通用 | 已实践（3 项目采用） | 少量（见冲突报告） | **KEEP** → core 骨架 |
| `E:\work\project\docs\ai\05_PROJECT_CONTEXT.md` | 通用目录 | 项目上下文填空模板 | 2026-06-05 | 活跃 | 通用模板 | 已实践 | 无 | MERGE → 05 模板（与十四节结构合并） |
| `E:\work\project\docs\ai\新建文本文档.txt` | 通用目录 | 治理框架说明书（05→01→02→03→04） | — | 活跃（used-car 已改名 README 使用） | 通用 | 已实践 | 阅读顺序与他源冲突 | REWRITE → README/治理规则 |
| `E:\work\project\CLAUDE.md` | 通用目录 | 通用入口（语言规范+Ponytail+协议） | 2026-06-25 | 活跃 | 通用 | 已实践 | 无 | KEEP → 入口模板骨架 |
| `E:\work\project\auto_wechat\CLAUDE.md / AGENTS.md` | auto_wechat | 演化版入口（硬约束+安全底线+自治维护） | 2026-07-14 | 活跃 | 混合 | 已实践（多轮治理） | 曾漂移（已修复） | PARAMETERIZE → 入口模板项目区设计 |
| `E:\work\project\auto_wechat\docs\ai\01~04` | auto_wechat | 演化版规则（+§17-22 等增量） | 2026-07-14 | 活跃 | 混合 | 已实践 | 项目事实泄漏在规则层 | MERGE+PARAMETERIZE → core 增量节 |
| `E:\work\project\auto_wechat\docs\ai\01 §18` | auto_wechat | AI 文档自治维护规则 | 2026-07-14 | 活跃 | 通用 | 已实践（基线重构验证） | 无 | KEEP → core/05_DOCUMENT_GOVERNANCE_RULES |
| `E:\work\project\auto_edit\CLAUDE.md(=AGENTS.md)` | auto_edit | 精简重写入口 | 2026-07-07 | 活跃 | 混合 | 已实践 | 风格与 A 系冲突（轻报告派） | MERGE → 懒惰阶梯/最小验证/产物禁提交进 core |
| `E:\work\project\auto_edit\docs\ai\*`（含 HANDOFF、archive 四分类） | auto_edit | 精简规则+交接快照+归档分类 | 2026-07 | 活跃 | 混合 | 已实践 | 域名词渗入规则层 | MERGE → HANDOFF 机制、archive 分类进治理规则 |
| `E:\work\project\used-car\CLAUDE.md` | used-car | A 系纯净入口实例 | 2026-07-07 | 活跃 | 通用 | 已实践 | 无 | KEEP → 入口模板主要参照 |
| `E:\work\project\used-car\docs\ai\*` | used-car | A 的逐字节拷贝 + 05 填写实例 | 2026-07 | 活跃 | 通用+项目 | 已实践 | 05§8 与 02 文件规模条目内部顶牛 | KEEP（作为分层最干净的参照）；顶牛点已在 core#5 显式裁决 |
| `E:\work\ponytail\AGENTS.md` | ponytail | Ponytail 懒惰开发规则规范原文 | — | 活跃 | 通用 | 已实践（多项目引用） | auto_wechat 副本有复制损坏 | KEEP → 入口模板采用规范原文 |
| `C:\Users\A\.claude\CLAUDE.md` | 用户全局 | 全局入口协议（语言/优先级/工作流/阅读顺序） | — | 活跃 | 通用 | 用户长期工作方式（最高优先级） | 阅读顺序裁决依据 | KEEP → 冲突裁决基准 |

## 未采用 / 未找到来源

| 目标 | 结果 | 原因 |
|---|---|---|
| `Vibecoding开发规范.md` | **未在 E:\work 下找到**（全深度文件名搜索无命中） | 无法核验内容；列入人工确认清单 |
| `ai_rules_updated_diff.patch` | **未在 E:\work 下找到** | 同上 |
| 此前生成的通用工具包/草案 | 未发现独立落盘目录 | 按任务要求仅作低优先级参考；本基线全部内容以已实践资产为来源 |
| `douyinAPI / NewCarPorject / car-porject-main / react` 的规则文件 | 无 CLAUDE/AGENTS/docs/ai 规则目录 | 这些项目未建规则体系，不构成来源 |
| `E:\work\project\project_info\*`、`模块分类.md`、`明日 Todo*.md` | 内容为需求/待办，非规则 | 不属于规则资产 |

## 搜索范围说明

- 定向文件名搜索：`E:\work`（全深度，排除 node_modules/dist/.git）匹配 CLAUDE/AGENTS/RULES/PROJECT_CONTEXT/Vibecoding/ai_rules/开发规范/编码规范/执行规范/*.patch。
- 未做业务代码全文遍历；仅在核验规则是否通用时定向查看应用证据。
