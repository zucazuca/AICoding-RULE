# 交接契约

所有正式交接使用结构化信封。状态行不能替代字段、差异或测试证据。

## 最小字段

~~~text
Task-ID:
Plan-Revision:
Plan-Identifier:
Plan-Hash:
Base-Commit:
Candidate-Commit:
Role:
Allowed-Files:
Forbidden-Files:
Acceptance-Matrix:
Environment:
Residual-Risks:
~~~

Plan-Identifier 与 Plan-Hash 至少提供一项。Candidate-Commit 在 PLAN_DRAFT、PLAN_APPROVED 和 IMPLEMENTING 阶段可以为空；进入 CANDIDATE_READY、代码审查和测试后必须是完整 Git 提交哈希。

## 完整哈希

完整哈希是当前仓库对象格式下由 Git 返回的未缩写提交对象 ID，必须满足：

1. 可由 git rev-parse --verify <value>^{commit} 唯一解析；
2. 回传值与 Git 输出逐字符一致；
3. 测试工作树的 git rev-parse HEAD 与 Candidate-Commit 一致；
4. 不使用分支名、标签、HEAD、相对引用或自然语言代称。

SHA-1 仓库通常为 40 位十六进制，SHA-256 仓库通常为 64 位；协议不把完整哈希错误地固定为某一种对象格式。

## 不可变候选提交

Candidate-Commit 是审批和测试共同引用的不可变审查对象。执行窗口回传 CANDIDATE_READY 后：

- 不再改变该提交；
- 不在同一候选上追加未提交业务代码；
- 本地提交不授予推送、合并或发布权限；
- 审批窗口核对 Base-Commit 到 Candidate-Commit 的实际差异；
- 测试窗口只检出并测试该 Candidate-Commit。

## 结果失效

以下任一动作产生新提交对象后，旧审批与测试结论不得用于新哈希：

- amend、rebase、squash、merge、cherry-pick；
- 冲突修复；
- 源码、规则、配置、迁移或测试代码变化；
- 构建/发布过程改变被验收的受控内容；
- 测试时 Actual-HEAD 与 Candidate-Commit 不一致。

推送同一个提交对象本身不改变哈希；但合并提交、发布制品或部署内容必须能追溯到被批准的 Candidate-Commit。

## 必须 REPLAN

出现以下情况不能由执行或测试窗口自行解释：

- 目标、范围或验收标准需要变化；
- Base-Commit 漂移导致计划假设失效；
- 数据合同、权限边界或迁移策略与计划冲突；
- Allowed-Files 不足以完成目标；
- 测试发现的是需求矛盾而非实现缺陷；
- R2 无法在冻结计划内完成。

REPLAN 必须废止旧 Plan-Revision；已有候选不能跨计划复用。

## CONDITIONAL_PASS

只有同时满足下列条件才允许：

- 核心功能已验证；
- 权限、安全、隔离和数据一致性已验证；
- 未执行项仅受非核心环境限制；
- 存在充分、可审计的替代证据；
- 报告列出补测条件、责任人和残余风险。

它不得掩盖失败、哈希不一致、权限/安全缺测或数据库迁移未验证。审批窗口可以拒绝该结论并返回 R1、R2 或 REPLAN。

## 原因码

原因码用于补充状态，不创建新的平行状态。例如：

~~~text
TEST_BLOCKED <full-hash> reason=BLOCKED_ENVIRONMENT
REPLAN <Task-ID> <Plan-Revision> <Base-Commit> reason=BASE_DRIFT
REJECT_SCOPE <Task-ID> <Plan-Revision> <Base-Commit> reason=SCOPE_CONFLICT
~~~

原因码永远不能替代状态或被解释为 PASS。
