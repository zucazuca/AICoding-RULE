<!--
  AICoding-RULE 项目模板：docs/ai/01_READING_RULES.md
  设计：受控区块（managed block）+ 项目扩展区。
  - 区块内内容由 Install-AICodingRule.ps1 从 core/01_READING_RULES.md 注入，
    项目内禁止手改；升级基线时重新注入并更新 version。
  - 项目专属阅读规则写在区块外的"项目扩展规则"区。
  这样项目文件自包含（AI 工具无需跨目录读取），
  同时 core 保持单一来源，漂移可被 Compare-ProjectRules.ps1 检测。
-->
<!-- AICODING-RULE:BEGIN name=core/01_READING_RULES version={{VERSION}} 区块内请勿手改，升级用 Install-AICodingRule.ps1 -->
{{CORE_01_READING_RULES_CONTENT}}
<!-- AICODING-RULE:END name=core/01_READING_RULES -->

------

# 项目扩展规则（01 阅读）

<!-- 项目区：项目专属的阅读要求写在这里，例如：
     - 附加必读登记（修改 X 前必读 Y 验收文档）
     - 项目特有的模块地图入口
     没有扩展时保留本节标题和"无"即可。 -->

无
