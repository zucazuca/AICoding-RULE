<!--
  AICoding-RULE 项目模板：docs/ai/02_EXECUTION_RULES.md
  设计：受控区块（managed block）+ 项目扩展区。
  - 区块内内容由 Install-AICodingRule.ps1 从 core/02_EXECUTION_RULES.md 注入，
    项目内禁止手改；升级基线时重新注入并更新 version。
  - 项目专属规则写在区块外的"项目扩展规则"区。
-->
<!-- AICODING-RULE:BEGIN name=core/02_EXECUTION_RULES version={{VERSION}} 区块内请勿手改，升级用 Install-AICodingRule.ps1 -->
{{CORE_02_EXECUTION_RULES_CONTENT}}
<!-- AICODING-RULE:END name=core/02_EXECUTION_RULES -->

------

# 项目扩展规则（02 执行）

<!-- 项目区：项目专属规则写在这里，例如：
     - 项目安全边界（发送门禁、自动化边界等）
     - 项目专属高风险日志场景清单
     - 项目产物 / 密钥禁提交追加项
     没有扩展时保留本节标题和"无"即可。 -->

无
