# P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1 交接快照

> 当前交接快照，供下一 VibeCoding 窗口继续工作时优先阅读。
> 这不是历史流水账；同一任务再次交接时应原位更新，不要追加互相矛盾的旧结论。

## 1. 当前结论

- Task-ID：`P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1`
- 仓库分支：`master`
- Base-Commit：`55504be034044bf9c42fbccf75c88337b365e30a`
- 功能提交：`bf442458c83ddb9d495f303c9aa26f4216b8e6f6`
- 复审修复提交：`61f12f48ce1666f1f4b42601b89f9eeded089b4a`
- 远端状态：上述两个提交已推送到 `origin/master`
- 当前版本：`0.2.0`
- 发布状态：未发布
- 实现状态：完成；没有已知 Critical 或 Important 实现缺口

本快照提交后，分支 HEAD 会是仅增加交接文档的后续提交；工作流实现与验证的证据锚仍是 `61f12f48ce1666f1f4b42601b89f9eeded089b4a`。

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

从 Base 到实现证据锚共变更 28 个文件：18 个新增、10 个修改、0 个删除，合计 1631 行新增、32 行删除。

## 4. 冻结设计决定

- 定位是 Optional Advanced Workflow，默认关闭。
- L0 默认单窗口或轻量审查；L1 可双窗口或轻量三窗口；L2 推荐完整三权；L3 必须完整三权并保留人工 Owner 的生产发布批准权。
- 唯一主路径包含 `PLAN_APPROVED -> IMPLEMENTING -> CANDIDATE_READY -> APPROVE_TEST -> TEST_REQUEST`。
- 执行窗口允许创建本地候选提交；本地提交不代表允许推送、合并或发布。
- 审批和独立测试绑定同一个完整 Candidate-Commit；候选回传后冻结。
- amend、rebase、squash、merge、cherry-pick、冲突修复或受控内容变化产生新对象后，旧审批、测试和 Owner 证据失效。
- 审批前验证 Base 是 Candidate 的祖先，并记录提交列表和父对象证据。
- 推送信封绑定 remote、ref、expected remote hash，模式固定为 fast-forward-only；本工作流禁止强制推送。
- 发布任务在测试阶段构建并验证一次不可变制品；发布只提升被测试和批准的同一摘要，不得重新构建。
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

关键结果：

```text
git diff --check                                      PASS
禁用旧流程词扫描                                     0 matches
外部素材目录词扫描                                   0 matches
命名模型/服务商扫描                                  0 matches
状态机表                                             20/20
五份模板必需字段                                     PASS
源仓库 Markdown 相对链接                             PASS
安装布局相对链接                                     23/23
Windows PowerShell                                   5.1.19041.6456
PowerShell 脚本解析与 UTF-8 BOM                      3/3
WhatIf                                               0 writes
默认安装                                             10 files；可选模块 absent
默认安装第二次                                       tree digest unchanged
Compare                                              4 MATCH；1 CUSTOM；0 DRIFT；0 MISSING
可选安装                                             25 files；15 optional SHA-256 matches
可选安装第二次                                       tree digest unchanged
可选安装最终摘要                                     46BEC61E2C26AF1A16A13B84DDD5237CBEF3665BEFE3C6230AB35A065203DFB2
Audit                                                WARN 0；模块已安装但默认关闭
已有规则不覆盖                                       PASS
可选文件漂移检测且不覆盖                             PASS
```

四份输入素材在任务结束时的 SHA-256 与开始读取时一致。正式交付内容没有素材目录引用或运行时依赖。

## 7. 已知残余风险

- 仓库没有 CI、Pester 或其他仓库自带自动化测试套件；本次使用真实 PowerShell 5.1 脚本和断言沙箱验证。
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

预期：分支为 `master`，工作区为空，HEAD 与 `origin/master` 一致。

没有必须继续施工的事项。若要增强，优先考虑为 Install/Audit 增加仓库内 PowerShell 5.1 回归测试；这属于新任务，必须重新确定范围并创建新提交，不得 amend 已推送提交。

禁止事项：不要把三个长 Prompt 加入 Required Reading；不要默认启用工作流；不要恢复旧的预提交审批流程；不要把 L0/L1 强制升级为完整三权；不要绕过不可变哈希、制品摘要或人工 Owner 边界。
