# Install-AICodingRule.ps1
# 将 AICoding-RULE 基线接入项目：只创建缺失文件，绝不覆盖已有规则。
# 用法：
#   .\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -WhatIf
#   .\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -Backup
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$RuleProfile = 'default',
    [switch]$Backup
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}
function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

# --- 定位基线与版本 ---
$BaselineRoot = Split-Path -Parent $PSScriptRoot
$VersionFile  = Join-Path $BaselineRoot 'VERSION'
if (-not (Test-Path $VersionFile)) { throw "找不到基线 VERSION 文件：$VersionFile" }
$Version = (Read-Utf8 $VersionFile).Trim()

if (-not (Test-Path $ProjectPath)) { throw "项目路径不存在：$ProjectPath" }
$ProjectPath = (Resolve-Path $ProjectPath).Path

Write-Host "== AICoding-RULE 安装 v$Version ==" -ForegroundColor Cyan
Write-Host "基线：$BaselineRoot"
Write-Host "项目：$ProjectPath"
Write-Host "Profile：$RuleProfile"
Write-Host ""

# --- 安装计划定义 ---
# type=entry：入口模板直接落地（保留 {{占位符}} 由 bootstrap 任务填写）
# type=managed：项目模板 + 将 core 内容注入受控区块
# type=plain：模板直接落地
$Plan = @(
    @{ Target = 'CLAUDE.md';                                  Type = 'entry';   Template = 'entry-templates\CLAUDE.template.md' }
    @{ Target = 'AGENTS.md';                                  Type = 'entry';   Template = 'entry-templates\AGENTS.template.md' }
    @{ Target = 'docs\ai\README.md';                          Type = 'plain';   Template = 'project-templates\docs-ai\README.template.md' }
    @{ Target = 'docs\ai\01_READING_RULES.md';                Type = 'managed'; Template = 'project-templates\docs-ai\01_READING_RULES.template.md';   Core = 'core\01_READING_RULES.md';   Token = '{{CORE_01_READING_RULES_CONTENT}}' }
    @{ Target = 'docs\ai\02_EXECUTION_RULES.md';              Type = 'managed'; Template = 'project-templates\docs-ai\02_EXECUTION_RULES.template.md'; Core = 'core\02_EXECUTION_RULES.md'; Token = '{{CORE_02_EXECUTION_RULES_CONTENT}}' }
    @{ Target = 'docs\ai\03_TESTING_RULES.md';                Type = 'managed'; Template = 'project-templates\docs-ai\03_TESTING_RULES.template.md';   Core = 'core\03_TESTING_RULES.md';   Token = '{{CORE_03_TESTING_RULES_CONTENT}}' }
    @{ Target = 'docs\ai\04_OUTPUT_RULES.md';                 Type = 'managed'; Template = 'project-templates\docs-ai\04_OUTPUT_RULES.template.md';    Core = 'core\04_OUTPUT_RULES.md';    Token = '{{CORE_04_OUTPUT_RULES_CONTENT}}' }
    @{ Target = 'docs\ai\05_PROJECT_CONTEXT.md';              Type = 'plain';   Template = 'project-templates\docs-ai\05_PROJECT_CONTEXT.template.md' }
    @{ Target = 'docs\ai\05_DOCUMENT_GOVERNANCE_RULES.md';    Type = 'plain';   Template = 'core\05_DOCUMENT_GOVERNANCE_RULES.md' }
)

# --- 第一步：审计现状并输出计划 ---
$ToCreate = @(); $Skipped = @()
foreach ($item in $Plan) {
    $targetFull = Join-Path $ProjectPath $item.Target
    if (Test-Path $targetFull) { $Skipped += $item.Target } else { $ToCreate += $item }
}

Write-Host "-- 计划 --" -ForegroundColor Cyan
foreach ($s in $Skipped)  { Write-Host "  跳过（已存在，禁止覆盖）：$s" -ForegroundColor Yellow }
foreach ($c in $ToCreate) { Write-Host "  创建：$($c.Target)" -ForegroundColor Green }
if ($Skipped.Count -gt 0) {
    Write-Host "  提示：已存在文件请用 Compare-ProjectRules.ps1 对比基线后人工合并。" -ForegroundColor Yellow
}
Write-Host ""

# --- 备份（仅在将写入 profile 且其已存在时需要；创建型动作不破坏现有内容） ---
$ProfilePath = Join-Path $ProjectPath '.aicoding-rule.json'
if ($Backup -and (Test-Path $ProfilePath)) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bak = "$ProfilePath.$stamp.bak"
    if ($PSCmdlet.ShouldProcess($ProfilePath, "备份到 $bak")) {
        Copy-Item $ProfilePath $bak
        Write-Host "已备份 profile：$bak"
    }
}

# --- 第二步：执行创建 ---
$Created = @()
foreach ($item in $ToCreate) {
    $targetFull = Join-Path $ProjectPath $item.Target
    $templateFull = Join-Path $BaselineRoot $item.Template
    $content = Read-Utf8 $templateFull
    if ($item.Type -eq 'managed') {
        $coreContent = (Read-Utf8 (Join-Path $BaselineRoot $item.Core)).TrimEnd()
        $content = $content.Replace($item.Token, $coreContent)
    }
    $content = $content.Replace('{{VERSION}}', $Version)
    if ($PSCmdlet.ShouldProcess($targetFull, '创建规则文件')) {
        $dir = Split-Path -Parent $targetFull
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Utf8 $targetFull $content
        $Created += $item.Target
    }
}

# --- 第三步：写入 / 更新 profile 标记 ---
$profileObj = [ordered]@{
    baselineVersion = $Version
    profile         = $RuleProfile
    installedAt     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    managedFiles    = @($Plan | Where-Object { $_.Type -eq 'managed' } | ForEach-Object { $_.Target.Replace('\', '/') })
    adapters        = @()   # 项目按需登记，如 "python-fastapi", "react-typescript"
}
if ($PSCmdlet.ShouldProcess($ProfilePath, '写入 .aicoding-rule.json（版本标记）')) {
    Write-Utf8 $ProfilePath (($profileObj | ConvertTo-Json -Depth 4))
}

# --- 摘要 ---
Write-Host ""
Write-Host "-- 结果摘要 --" -ForegroundColor Cyan
Write-Host "创建：$($Created.Count) 个文件"
$Created | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
Write-Host "跳过：$($Skipped.Count) 个已存在文件（未做任何修改）"
Write-Host "后续：填写 05_PROJECT_CONTEXT.md 与入口文件 {{占位符}}（见 prompts/project-bootstrap.md）"
