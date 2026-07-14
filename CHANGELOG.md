# CHANGELOG

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
