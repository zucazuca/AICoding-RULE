<!--
  AICoding-RULE 项目模板：docs/ai/04_OUTPUT_RULES.md
  设计：受控区块（managed block）+ 项目扩展区。
  - 区块内内容由 Install-AICodingRule.ps1 从 core/04_OUTPUT_RULES.md 注入，
    项目内禁止手改；升级基线时重新注入并更新 version。
  - 项目专属规则写在区块外的"项目扩展规则"区。
-->
<!-- AICODING-RULE:BEGIN name=core/04_OUTPUT_RULES version={{VERSION}} 区块内请勿手改，升级用 Install-AICodingRule.ps1 -->
{{CORE_04_OUTPUT_RULES_CONTENT}}
<!-- AICODING-RULE:END name=core/04_OUTPUT_RULES -->

------

# 项目扩展规则（04 输出）

<!-- 项目区：项目专属规则写在这里，例如：
     - 项目追加的完成报告项（如：是否调用真实 LLM）
     没有扩展时保留本节标题和"无"即可。 -->

无
