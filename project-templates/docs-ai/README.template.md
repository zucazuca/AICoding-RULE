<!--
  AICoding-RULE 项目模板：docs/ai/README.md
  由 Install-AICodingRule.ps1 在项目缺少 docs/ai/README.md 时生成。
-->
# {{PROJECT_NAME}} AI 文档索引

本目录用于保存 AI 协作规则、项目上下文、专题文档和归档。

开始任何任务前，仍必须先按根目录入口文件要求阅读：

```text
CLAUDE.md（或 AGENTS.md）
docs/ai/01_READING_RULES.md
docs/ai/05_PROJECT_CONTEXT.md
docs/ai/02_EXECUTION_RULES.md
docs/ai/03_TESTING_RULES.md
docs/ai/04_OUTPUT_RULES.md
```

`docs/ai` 根目录只保留入口规则和项目上下文，专题文档按业务域归档。

## 根目录入口

| 文件 | 用途 |
|---|---|
| `01_READING_RULES.md` | 阅读和理解项目的强制规则 |
| `02_EXECUTION_RULES.md` | 执行、风险、日志、安全边界 |
| `03_TESTING_RULES.md` | 测试和验收规则 |
| `04_OUTPUT_RULES.md` | 汇报格式和风险说明 |
| `05_PROJECT_CONTEXT.md` | **当前项目事实文档**（只保存当前有效上下文，不记录里程碑流水账） |
| `05_DOCUMENT_GOVERNANCE_RULES.md` | 文档治理与自治维护规则（如单独安装） |

## 专题目录

<!-- 按项目实际业务域调整；小型项目可只用 archive/ 四分类 -->

| 目录 | 内容 |
|---|---|
| `{{TOPIC_DIR_1}}/` | {{TOPIC_DESC_1}} |
| `archive/` | 冻结历史快照（非当前事实，仅追溯用） |

## 当前常用入口

| 场景 | 推荐阅读 |
|---|---|
| {{SCENE_1}} | `{{DOC_PATH_1}}` |

## 可选高级工作流

Three-Authority VibeCoding Governance 默认关闭，不属于上述 Required Reading。只有任务经过风险分级并显式启用、且项目已安装可选模块后，才按需进入：

~~~text
docs/ai/workflows/three-authority-vibecoding/README.md
~~~

## 历史追溯 / 归档入口

以下文件**不是当前项目事实**，普通任务不得默认读取；仅在追溯历史决策或旧结论来源时按需读取：

| 内容 | 文件 |
|---|---|
| {{ARCHIVE_DESC}} | `archive/{{ARCHIVE_FILE}}` |

## 归档规则

1. 新文档优先写入对应专题目录，不再堆到 `docs/ai` 根目录。
2. 规则类文档继续保留在根目录，避免入口路径频繁变化。
3. 历史任务文档保留原文件名，通过目录表达归属。
4. 移动文档时必须同步更新入口文件与本 README 的关键链接。
5. 归档文件头部必须注明"冻结快照 / 非当前事实"。
