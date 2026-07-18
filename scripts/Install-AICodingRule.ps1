# Install-AICodingRule.ps1
# 将 AICoding-RULE 基线接入项目：只创建缺失文件，绝不覆盖已有规则。
# 用法：
#   .\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -WhatIf
#   .\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -Backup
#   .\Install-AICodingRule.ps1 -ProjectPath E:\work\project\demo -IncludeThreeAuthorityWorkflow
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$RuleProfile = 'default',
    [switch]$Backup,
    [switch]$IncludeThreeAuthorityWorkflow
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
# type=copy：逐字节复制可选模块，不替换任何占位符
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

if ($IncludeThreeAuthorityWorkflow) {
    $optionalMappings = @(
        @{
            Source = 'workflows\three-authority-vibecoding'
            Target = 'docs\ai\workflows\three-authority-vibecoding'
        }
        @{
            Source = 'prompts\three-authority-vibecoding'
            Target = 'docs\ai\prompts\three-authority-vibecoding'
        }
        @{
            Source = 'templates\three-authority-vibecoding'
            Target = 'docs\ai\templates\three-authority-vibecoding'
        }
    )

    foreach ($mapping in $optionalMappings) {
        $sourceRoot = Join-Path $BaselineRoot $mapping.Source
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            throw "可选工作流源目录不存在：$sourceRoot"
        }

        $sourceFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName
        foreach ($sourceFile in $sourceFiles) {
            $relativePath = $sourceFile.FullName.Substring($sourceRoot.Length).TrimStart([char[]]@('\', '/'))
            $Plan += @{
                Target   = Join-Path $mapping.Target $relativePath
                Type     = 'copy'
                Template = Join-Path $mapping.Source $relativePath
                Optional = $true
            }
        }
    }
}

$duplicateTargets = @(
    $Plan |
        Group-Object -Property { $_.Target.ToLowerInvariant() } |
        Where-Object { $_.Count -gt 1 }
)
if ($duplicateTargets.Count -gt 0) {
    $duplicates = ($duplicateTargets | ForEach-Object { $_.Group[0].Target }) -join ', '
    throw "安装计划包含重复目标：$duplicates"
}

# --- 第一步：审计现状并输出计划 ---
$ToCreate = @(); $Skipped = @()
foreach ($item in $Plan) {
    $targetFull = Join-Path $ProjectPath $item.Target
    if (Test-Path -LiteralPath $targetFull) {
        if (-not (Test-Path -LiteralPath $targetFull -PathType Leaf)) {
            throw "安装目标已存在但不是文件，拒绝继续：$targetFull"
        }
        $Skipped += $item.Target
    } else {
        $ToCreate += $item
    }
}

Write-Host "-- 计划 --" -ForegroundColor Cyan
foreach ($s in $Skipped)  { Write-Host "  跳过（已存在，禁止覆盖）：$s" -ForegroundColor Yellow }
foreach ($c in $ToCreate) {
    $label = if ($c.Optional) { '创建（可选，默认关闭）' } else { '创建' }
    Write-Host "  $($label)：$($c.Target)" -ForegroundColor Green
}
if ($Skipped.Count -gt 0) {
    Write-Host "  提示：已存在文件请用 Compare-ProjectRules.ps1 对比基线后人工合并。" -ForegroundColor Yellow
}
Write-Host ""

$ProfilePath = Join-Path $ProjectPath '.aicoding-rule.json'
$profileExists = Test-Path -LiteralPath $ProfilePath
$profileObj = $null
if ($profileExists) {
    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
        throw "Profile 路径已存在但不是文件，拒绝继续：$ProfilePath"
    }
    $profileText = Read-Utf8 $ProfilePath
    if (-not $profileText.TrimStart().StartsWith('{')) {
        throw '现有 .aicoding-rule.json 顶层必须是 JSON object，拒绝覆盖。'
    }
    try {
        $profileObj = $profileText | ConvertFrom-Json
    } catch {
        throw "现有 .aicoding-rule.json 不是合法 JSON，拒绝覆盖：$($_.Exception.Message)"
    }
    if (-not ($profileObj -is [System.Management.Automation.PSCustomObject])) {
        throw '现有 .aicoding-rule.json 顶层必须是 JSON object，拒绝覆盖。'
    }
}

# --- 第二步：执行创建 ---
$Created = @()
foreach ($item in $ToCreate) {
    $targetFull = Join-Path $ProjectPath $item.Target
    $templateFull = Join-Path $BaselineRoot $item.Template

    if ($item.Type -eq 'copy') {
        if ($PSCmdlet.ShouldProcess($targetFull, '复制可选工作流文件')) {
            $dir = Split-Path -Parent $targetFull
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item -LiteralPath $templateFull -Destination $targetFull
            $Created += $item.Target
        }
        continue
    }

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

# --- 第三步：创建或合并 profile 标记 ---
function Set-ProfileProperty([object]$Object, [string]$Name, $Value) {
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $property.Value = $Value
    }
}

$requiredManagedFiles = @(
    $Plan |
        Where-Object { $_.Type -eq 'managed' } |
        ForEach-Object { $_.Target.Replace('\', '/') }
)

$allManagedCurrent = $true
foreach ($managedItem in @($Plan | Where-Object { $_.Type -eq 'managed' })) {
    $managedPath = Join-Path $ProjectPath $managedItem.Target
    if (-not (Test-Path -LiteralPath $managedPath -PathType Leaf)) {
        $allManagedCurrent = $false
        break
    }

    $managedName = $managedItem.Core.Replace('\', '/') -replace '\.md$', ''
    $markerPattern = 'AICODING-RULE:BEGIN\s+name=' +
        [regex]::Escape($managedName) +
        '\s+version=' +
        [regex]::Escape($Version) +
        '(?:\s|-->)'
    if ((Read-Utf8 $managedPath) -notmatch $markerPattern) {
        $allManagedCurrent = $false
        break
    }
}

$profileNeedsWrite = $false
$profileAction = '保留（无变化）'

if ($profileExists) {
    if ($null -eq $profileObj.PSObject.Properties['baselineVersion']) {
        Set-ProfileProperty $profileObj 'baselineVersion' $Version
        $profileNeedsWrite = $true
    } elseif ($allManagedCurrent -and [string]$profileObj.baselineVersion -ne $Version) {
        Set-ProfileProperty $profileObj 'baselineVersion' $Version
        $profileNeedsWrite = $true
    }

    if ($null -eq $profileObj.PSObject.Properties['profile']) {
        Set-ProfileProperty $profileObj 'profile' $RuleProfile
        $profileNeedsWrite = $true
    } elseif ($PSBoundParameters.ContainsKey('RuleProfile') -and [string]$profileObj.profile -ne $RuleProfile) {
        Set-ProfileProperty $profileObj 'profile' $RuleProfile
        $profileNeedsWrite = $true
    }

    if ($null -eq $profileObj.PSObject.Properties['installedAt']) {
        Set-ProfileProperty $profileObj 'installedAt' (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $profileNeedsWrite = $true
    }

    $mergedManagedFiles = New-Object System.Collections.ArrayList
    foreach ($managedFile in @($profileObj.managedFiles) + $requiredManagedFiles) {
        if ($null -eq $managedFile) { continue }
        $normalizedManagedFile = ([string]$managedFile).Replace('\', '/')
        if (-not ($mergedManagedFiles -contains $normalizedManagedFile)) {
            [void]$mergedManagedFiles.Add($normalizedManagedFile)
        }
    }
    $existingManagedFiles = @($profileObj.managedFiles)
    if (
        $null -eq $profileObj.PSObject.Properties['managedFiles'] -or
        $existingManagedFiles.Count -ne $mergedManagedFiles.Count -or
        (Compare-Object -ReferenceObject $existingManagedFiles -DifferenceObject @($mergedManagedFiles))
    ) {
        Set-ProfileProperty $profileObj 'managedFiles' @($mergedManagedFiles)
        $profileNeedsWrite = $true
    }

    if ($null -eq $profileObj.PSObject.Properties['adapters']) {
        Set-ProfileProperty $profileObj 'adapters' @()
        $profileNeedsWrite = $true
    }
} else {
    $profileObj = [ordered]@{
        baselineVersion = $Version
        profile         = $RuleProfile
        installedAt     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        managedFiles    = $requiredManagedFiles
        adapters        = @()
    }
    $profileNeedsWrite = $true
}

if ($profileNeedsWrite) {
    if ($Backup -and $profileExists) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $bak = "$ProfilePath.$stamp.bak"
        if ($PSCmdlet.ShouldProcess($ProfilePath, "备份到 $bak")) {
            Copy-Item -LiteralPath $ProfilePath -Destination $bak
            Write-Host "已备份 profile：$bak"
        }
    }
    if ($PSCmdlet.ShouldProcess($ProfilePath, '写入 .aicoding-rule.json（合并版本标记）')) {
        Write-Utf8 $ProfilePath (($profileObj | ConvertTo-Json -Depth 100))
        $profileAction = if ($profileExists) { '合并更新' } else { '创建' }
    } else {
        $profileAction = '计划写入（WhatIf）'
    }
}

# --- 摘要 ---
Write-Host ""
Write-Host "-- 结果摘要 --" -ForegroundColor Cyan
Write-Host "创建：$($Created.Count) 个文件"
$Created | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
Write-Host "跳过：$($Skipped.Count) 个已存在文件（未做任何修改）"
Write-Host "Profile：$profileAction"
if ($IncludeThreeAuthorityWorkflow) {
    Write-Host "可选工作流入口：docs\ai\workflows\three-authority-vibecoding\README.md"
    $optionalItems = @($Plan | Where-Object { $_.Optional })
    $optionalInstalledCount = 0
    foreach ($optionalItem in $optionalItems) {
        $optionalTarget = Join-Path $ProjectPath $optionalItem.Target
        if (Test-Path -LiteralPath $optionalTarget -PathType Leaf) {
            $optionalInstalledCount++
        }
    }
    $optionalPendingCount = @($ToCreate | Where-Object { $_.Optional }).Count
    if ($WhatIfPreference -and $optionalPendingCount -gt 0) {
        Write-Host "状态：计划安装或补齐（WhatIf 未写入；当前 $optionalInstalledCount/$($optionalItems.Count)），完成后仍默认关闭。"
    } elseif ($optionalInstalledCount -eq $optionalItems.Count) {
        Write-Host "状态：已安装但默认关闭，按风险显式启用。"
    } elseif ($optionalInstalledCount -gt 0) {
        Write-Host "状态：部分安装（$optionalInstalledCount/$($optionalItems.Count)），不得启用；重新运行安装或人工处理冲突。" -ForegroundColor Yellow
    } else {
        Write-Host "状态：未安装（写操作未执行）。" -ForegroundColor Yellow
    }
}
Write-Host "后续：填写 05_PROJECT_CONTEXT.md 与入口文件 {{占位符}}（见 prompts/project-bootstrap.md）"
