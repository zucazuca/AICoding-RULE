# 三权工作流状态契约修复设计

## 1. 背景

三权工作流已经定义“推送失败后重新规划”和“发布制品失效后重新测试或重新规划”，但唯一状态机没有为 `APPROVE_PUSH`、`APPROVE_RELEASE` 声明对应失败出口。同时，候选提交已经产生后，部分审批提示词仍输出无候选阶段使用的任务三元组，违反状态行必须绑定完整候选提交哈希的约束。

本次修复只统一既有契约，不增加新的治理状态，不改变模块默认关闭和按 L0～L3 逐任务判定的启用方式。

## 2. 目标与非目标

目标：

- 让状态机覆盖批准推送、批准发布后的真实失败路径。
- 让候选阶段的所有状态行统一绑定完整候选提交哈希。
- 让状态机、交接契约、角色提示词、模板、示例和使用说明保持一致。
- 增加无第三方依赖的静态自检，阻止同类语义漂移再次进入版本。
- 将修复作为补丁版本发布，并安全同步到已安装模块的 `gaozong` 项目。

非目标：

- 不新增 `PUSH_BLOCKED`、`RELEASE_BLOCKED` 等状态。
- 不改变三权模块的安装清单、默认阅读清单或任务启用策略。
- 不让安装器覆盖项目中已存在的文件。
- 不向 `gaozong` 复制上游版本、变更记录、规则画像或自检脚本。

## 3. 状态契约

保留现有状态集合，只补齐以下合法转换：

| 当前状态 | 合法下一状态 | 适用条件 |
|---|---|---|
| `APPROVE_PUSH` | `PUSHED` | 推送成功且远端证据可验证 |
| `APPROVE_PUSH` | `REPLAN` | 远端漂移、推送失败或推送前提失效 |
| `APPROVE_RELEASE` | `RELEASED` | 制品和发布动作均成功 |
| `APPROVE_RELEASE` | `TEST_REQUEST` | 制品缺失、摘要变化或需要重新生成并验证 |
| `APPROVE_RELEASE` | `REPLAN` | 部署策略、目标环境或发布前提失效 |

失败状态必须由实际执行结果触发，不能把失败动作伪装成成功状态。

状态输出权责保持三权分离：执行窗口只回报推送或发布动作的结果与失败证据，不自行裁决下一状态；审批窗口根据证据输出 `PUSHED`、`RELEASED`、`TEST_REQUEST` 或 `REPLAN`。

## 4. 状态行绑定规则

状态行按候选提交是否存在分为两个阶段：

- 候选提交产生前：`REPLAN <Task-ID> <Plan-Revision> <Base-Commit>` 或 `REJECT_SCOPE <Task-ID> <Plan-Revision> <Base-Commit>`。
- 候选提交产生后：`REPLAN <full-candidate-hash>` 或 `REJECT_SCOPE <full-candidate-hash>`。

候选阶段仍须在结构化交接信封中保留 `Task-ID`、`Plan-Revision`、`Base-Commit` 等字段；状态行不再重复这些字段。短哈希、分支名和 `HEAD` 均不能替代完整候选提交哈希。

## 5. 修改范围

上游仓库中预计修改：

- `workflows/three-authority-vibecoding/state-machine.md`
- `workflows/three-authority-vibecoding/handoff-contract.md`
- `workflows/three-authority-vibecoding/README.md`
- `workflows/three-authority-vibecoding/examples.md`
- `prompts/three-authority-vibecoding/approver-window.md`
- `prompts/three-authority-vibecoding/executor-window.md`
- `templates/three-authority-vibecoding/approval-record.md`
- `USAGE.md`
- `README.md` 中的脚本清单与自检入口
- `scripts/Test-ThreeAuthorityWorkflow.ps1`
- `CHANGELOG.md` 的未发布修复记录
- `reports/P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1-HANDOFF.md` 当前任务交接快照

实际实现以最小一致性差异为准；没有契约变化的文件不修改。

## 6. 静态自检

新增 PowerShell 自检脚本，不引入测试框架或依赖。至少验证：

1. 状态表包含 `APPROVE_PUSH -> REPLAN`。
2. 状态表包含 `APPROVE_RELEASE -> TEST_REQUEST | REPLAN`。
3. 审批提示词的“候选审查”和“最终裁决”两个阶段均不存在任务三元组形式的 `REPLAN`、`REJECT_SCOPE` 状态行。
4. 交接契约明确区分候选产生前后的状态行格式。
5. 候选阶段的审批提示词、审批模板和示例要求使用完整候选提交哈希。
6. 执行窗口只回报动作结果和证据，下一状态仍由审批窗口裁决。
7. 工作流 README 与 `USAGE.md` 覆盖推送和发布失败路径。

脚本任一断言失败时返回非零退出码，并输出可定位的中文错误信息。

交付验证分成两层：先运行上述只读静态自检；再在临时沙箱中预演并安装三权模块，运行既有 `Audit-AICodingRule.ps1` 核对必需文件与哈希。相对链接使用独立只读检查核对，避免把既有审计能力写得比实际更宽。

## 7. 版本与同步

本次不修改 core，因此全局 `VERSION` 和规则画像示例仍保持 `0.2.0`。如果仅因可选模块修复提升全局版本，现有 `0.2.0` core 受控区块会被 `Audit-AICodingRule.ps1` 误报为落后；引入模块独立版本机制又超出本次最小修复范围。`CHANGELOG.md` 增加未发布修复记录，当前交接快照记录经验证的规则实现提交完整哈希，以此标识本次模块修复。

上游验证并提交后，只把实际变化的分发文件同步到 `I:\work\gaozong`。同步清单明确排除上游 `README.md`、`CHANGELOG.md`、自检脚本和交接报告。同步后记录上游完整提交哈希、实际文件清单和逐文件 SHA-256，并核对相对链接、既有项目审计和 Git 差异，保持“模块安装不等于任务启用”。

## 8. 风险控制

- 状态爆炸：通过复用 `REPLAN`、`TEST_REQUEST` 避免新增状态。
- 误回退错误候选：候选阶段统一使用完整候选提交哈希。
- 上游与项目副本漂移：先提交上游，再按已变更分发文件逐项同步并核对哈希。
- 文档结论陈旧：当前交接快照原位更新，不追加互相矛盾的新旧结论。
- 安装器误覆盖：仍保持只创建缺失文件，不承担已安装模块升级。
- 基线版本误报：可选模块修复不提升全局 core 版本，避免让既有受控区块产生虚假升级警告。
