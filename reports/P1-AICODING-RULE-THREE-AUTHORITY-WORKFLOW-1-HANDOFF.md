# P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1 交接快照

> 当前交接快照，供下一 VibeCoding 窗口继续工作时优先阅读。
> 这不是历史流水账；同一任务再次交接时应原位更新，不要追加互相矛盾的旧结论。

## 1. 当前结论

- Task-ID：`P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1`
- 仓库分支：`fix/three-authority-state-contract`
- 本轮修复基线：`02d5dfe`（状态契约修复计划提交）
- 功能提交：`bf442458c83ddb9d495f303c9aa26f4216b8e6f6`
- 复审修复提交：`61f12f48ce1666f1f4b42601b89f9eeded089b4a`
- 状态契约修复提交：`4c250967f2250436aad9a7eb94fdec72ade7bf50`
- 远端验收锚：以 `origin/master` 是否包含上述状态契约修复提交为准，读取本快照时必须实时核验
- 当前版本：`0.2.0`
- 发布状态：未发布
- 实现状态：修复完成并通过规格、技术、产品和安全复核；没有已知 Critical 或 Important 实现缺口

本快照提交后，分支 HEAD 会是仅更新交接文档的后续提交；本轮实现与验证的证据锚始终是 `4c250967f2250436aad9a7eb94fdec72ade7bf50`，不使用本快照自引用。

## 2. 建议阅读顺序

1. 本交接快照；
2. [仓库 README](../README.md) 与 [使用指南](../USAGE.md)；
3. [工作流入口](../workflows/three-authority-vibecoding/README.md)；
4. [启用规则](../workflows/three-authority-vibecoding/activation-rules.md)；
5. [唯一状态机](../workflows/three-authority-vibecoding/state-machine.md)；
6. [交接契约](../workflows/three-authority-vibecoding/handoff-contract.md)；
7. 只有承担对应角色时，才读取[角色 Prompt 索引](../prompts/three-authority-vibecoding/README.md)和[模板索引](../templates/three-authority-vibecoding/README.md)。

三个长 Prompt 不属于默认 Required Reading。

## 3. 已落地内容

实际目录映射：

```text
workflows/three-authority-vibecoding/   工作流总则、启用规则、状态机、交接契约、示例
prompts/three-authority-vibecoding/     审批、执行、测试三个角色 Prompt
templates/three-authority-vibecoding/   五类正式交接模板
```

根 README、USAGE、核心执行规则和项目 README 模板只保留默认关闭的轻量入口。安装器通过 `-IncludeThreeAuthorityWorkflow` 按需复制完整模块；普通安装不复制也不启用该模块。

本轮状态契约修复提交精确变更 11 个文件：新增 1 个永久自检脚本，修改 10 个契约、提示、模板和入口文档，共 654 行新增、34 行删除。安装映射、审计映射、VERSION、schema、core、entry-templates 和 project-templates 均未修改；可选模块仍是原有 15 个文件。

## 4. 冻结设计决定

- 定位是 Optional Advanced Workflow，默认关闭。
- L0 默认单窗口或轻量审查；L1 可双窗口或轻量三窗口；L2 推荐完整三权；L3 必须完整三权并保留人工 Owner 的生产发布批准权。
- 唯一主路径包含 `PLAN_APPROVED -> IMPLEMENTING -> CANDIDATE_READY -> APPROVE_TEST -> TEST_REQUEST`。
- 执行窗口允许创建本地候选提交；本地提交不代表允许推送、合并或发布。
- 审批和独立测试绑定同一个完整 Candidate-Commit；候选回传后冻结。
- amend、rebase、squash、merge、cherry-pick、冲突修复或受控内容变化产生新对象后，旧审批、测试和 Owner 证据失效。
- 审批前验证 Base 是 Candidate 的祖先，并记录提交列表和父对象证据。
- 推送信封绑定 remote、ref、expected remote hash，模式固定为 fast-forward-only；本工作流禁止强制推送。
- 推送命令返回非零或异常后仍以精确 Push-Ref 的远端实际哈希为准；实际哈希等于 Candidate-Commit 时输出 PUSHED，否则只回传证据，由审批窗口裁决 REPLAN。
- 发布任务在测试阶段构建并验证一次不可变制品；发布只提升被测试和批准的同一摘要，不得重新构建。
- 发布前制品失效且没有部署副作用时回到 TEST_REQUEST；部署策略、目标环境或其他发布前提失效时 REPLAN；发布开始后的失败、部分成功或未知结果也 REPLAN。
- 只有每个目标的实际 Artifact-Digest 均与批准摘要一致且健康检查均通过，才可输出 RELEASED；旧 APPROVE_RELEASE 和适用的 Owner-Evidence 不得重放。
- 制品摘要对所有发布都必须绑定；人工 Owner 证据仅在 L3 或项目策略要求时必须绑定。
- 测试环境阻塞、哈希不一致和关键未测都不等于通过。
- 角色和流程不绑定模型或服务商。

## 5. 安装与治理行为

- 安装结果自包含，不依赖仓库外目录，不使用链接文件。
- Install 只创建缺失文件，已有规则保持不覆盖。
- 重复安装不重写未变化的 profile，并保留 adapters、overrides、installedAt 和未知扩展字段。
- 可选模块的 15 个文件逐字节复制；Install 与 Audit 都会报告内容漂移，但不会覆盖定制文件。
- 可选模块未安装时，Audit 保持中性。
- Compare 继续负责核心受控规则；可选模块完整性和内容差异由 Audit 报告并交人工合并。
- schema 没有新增字段，只同步 profile 示例版本。

## 6. 已执行验证

本轮关键结果：

```text
回归基线                                             79 checks；36 failures
状态机与交接契约修复后                               79 checks；22 failures
推送异常但远端成功边界（RED）                       83 checks；4 failures
推送对账修复后                                       83 checks；0 failures
最终多角色审查新增边界（RED）                       95 checks；10 failures
永久静态自检                                         95 checks；0 failures
真实安装与审计冒烟                                   122 checks；0 failures
状态集合                                             20/20；转换表与主路径闭包 PASS
PowerShell 脚本解析                                  0 errors
git diff --check                                     PASS
修改范围                                             11/11；禁改文件 0
WhatIf                                               0 writes；目标整树不变
默认安装                                             三权模块 absent
可选安装                                             15 optional SHA-256 matches
可选安装第二次                                       tree digest unchanged
Audit                                                exit 0；WARN 0；整树不变
临时沙箱                                             已清理；残留 0
VERSION / schema                                     0.2.0 / 0.2.0
```

永久自检命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1 -RunInstallSmoke
```

## 7. 已知残余风险

- 仓库仍没有 CI 或 Pester；已新增可直接运行的 PowerShell 5.1 永久自检，但需要本地或后续 CI 显式调用。
- Compare 将普通文件形式的 `core/05_DOCUMENT_GOVERNANCE_RULES` 报为 `CUSTOM`，这是既有架构行为，不是本任务引入的漂移。
- 新安装项目的 Audit 会把 CLAUDE/AGENTS 预期措辞差异列为 INFO；验证中 WARN 为 0。
- 发布制品证据链目前是治理协议和模板，不包含具体制品仓库的技术实现；项目必须在执行包中冻结实际构建、摘要和提升命令。

## 8. 下一窗口动作

开始前执行：

```powershell
git status --short
git branch --show-current
git rev-parse HEAD
git log -5 --oneline
```

若 `origin/master` 尚未包含 `4c250967f2250436aad9a7eb94fdec72ade7bf50`，先完成分支集成与推送；若已包含，则本仓库没有必须继续施工的事项。下游项目只同步本实现提交实际修改的 7 个三权模块文件，不同步根 README、USAGE、CHANGELOG、自检脚本、报告或计划。

最终验收：工作区为空，`master` 与 `origin/master` 一致，且 `git branch -r --contains 4c250967f2250436aad9a7eb94fdec72ade7bf50` 包含 `origin/master`。

禁止事项：不要把三个长 Prompt 加入 Required Reading；不要默认启用工作流；不要恢复旧的预提交审批流程；不要把 L0/L1 强制升级为完整三权；不要绕过不可变哈希、制品摘要或人工 Owner 边界。
