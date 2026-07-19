# CHANGELOG

## 未发布

- 修复候选创建后 REPLAN、REJECT_SCOPE 等裁决状态未绑定完整候选哈希的问题。
- 增加推送后精确引用的远端实际哈希对账，并统一失败或未知结果的证据回传与重新规划。
- 按发布前制品失效与发布后部署副作用分流，禁止重放旧批准和 Owner 证据。
- 增加三权工作流永久自检，覆盖状态、角色、失败分支、安装幂等和审计结果。

## 0.2.0（2026-07-18）

新增可选高级治理能力（P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1）。

- 新增 Three-Authority VibeCoding Governance：风险分级、唯一状态机、完整哈希交接契约和五类示例。
- 新增审批、执行、测试三个模型无关角色 Prompt，以及五份结构化交接模板。
- 统一为“本地候选提交 → 候选审查 → 独立测试”的不可变哈希证据链；候选变化必须重新审查和测试。
- 核心规则只增加默认关闭的轻量入口；三个长 Prompt 不进入 Required Reading。
- Install 新增可选模块安装开关；启用后的项目文件自包含，不依赖跨目录读取。
- 修复重复安装重写 profile、清空 adapters/overrides 的问题，保持幂等和合法扩展字段。

## 0.1.0（2026-07-14）

首个可复用基线（P0-AICODING-RULE-REUSABLE-BASELINE-1）。

- core 01~04：以 `E:\work\project\docs\ai`（三项目实践验证的原始通用模板）为骨架，
  合并 auto_wechat 演化增量（阶段总控、Bug 修复前置探索与根因门、高风险日志骨架、
  诊断接口安全序列化、环境性失败基线模式、完成报告 11 项）与 auto_edit 增量
  （懒惰开发阶梯、最小有效验证、产物/密钥禁提交），项目事实全部参数化剥离。
- core 05：文档治理与自治维护规则（源自 auto_wechat 2026-07-14 基线重构落地机制 +
  auto_edit 归档四分类 / HANDOFF 机制通用化）。
- 入口模板：used-car 纯净入口 + ponytail 规范原文 + auto_wechat 项目区结构，双入口等效。
- 项目模板：受控区块 + 项目扩展区设计；05 十四节当前事实文档模板。
- adapters：python-fastapi / react-typescript / postgresql / docker-compose /
  windows-powershell / local-gui-automation 六个实践蒸馏适配器。
- scripts：Install（默认不覆盖、-WhatIf/-Backup）/ Audit / Compare。
- reports：规则来源清单、冲突裁决报告（含人工确认清单）。
