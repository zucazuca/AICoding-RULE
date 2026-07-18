# 三权工作流状态契约修复实施计划

> **供智能执行者：** 必须使用 subagent-driven-development（推荐）或 executing-plans，按复选框逐项执行和复核。

**目标：** 修复三权工作流批准推送、批准发布后的失败出口和候选状态行绑定漂移，增加永久自检，并把实际变化的分发文件同步到 gaozong。

**架构：** 保留既有 20 个状态，由状态机继续充当唯一事实源；执行窗口只回报动作事实和对账证据，审批窗口输出 TEST_REQUEST、REPLAN 或 REJECT_SCOPE。新增一个无第三方依赖的 PowerShell 5.1 自检脚本，默认只读检查静态契约，显式开启时才在临时目录做安装冒烟测试。

**技术栈：** Markdown、Git、Windows PowerShell 5.1、SHA-256。

---

## 文件结构

上游新增：

- docs/superpowers/plans/2026-07-19-three-authority-state-contract-fix.md：本实施计划。
- scripts/Test-ThreeAuthorityWorkflow.ps1：静态契约与可选安装冒烟自检。

上游修改：

- workflows/three-authority-vibecoding/state-machine.md：唯一状态、合法转换和批准动作失败原则。
- workflows/three-authority-vibecoding/handoff-contract.md：推送和发布结果对账、候选前后状态格式、原因码。
- workflows/three-authority-vibecoding/README.md：失败主路径和角色边界。
- workflows/three-authority-vibecoding/examples.md：推送失败、制品失效、部分发布示例。
- prompts/three-authority-vibecoding/approver-window.md：候选阶段完整哈希和失败裁决。
- prompts/three-authority-vibecoding/executor-window.md：只回报结果和证据，不越权输出审批状态。
- templates/three-authority-vibecoding/approval-record.md：表达 FAILED、UNKNOWN、PARTIAL 的动作结果。
- README.md：脚本清单和自检入口。
- USAGE.md：候选格式、失败路径、自检用法。
- CHANGELOG.md：未发布修复记录。
- reports/P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1-HANDOFF.md：当前任务证据锚和验证快照。

明确不修改：

- VERSION、schemas/project-rule-profile.example.json、core、Install-AICodingRule.ps1、Audit-AICodingRule.ps1。
- 三权模块的 15 文件安装集合、默认关闭策略、Required Reading。
- gaozong 的 .aicoding-rule.json、默认入口启用说明和非本任务文件。

## 任务 1：建立会失败的永久自检

**文件：**

- 新建：scripts/Test-ThreeAuthorityWorkflow.ps1

- [ ] **步骤 1：新增完整自检脚本**

使用 apply_patch 新建下列文件；脚本默认不写仓库，只有 RunInstallSmoke 开关会创建并清理自己的临时目录。

~~~powershell
# Test-ThreeAuthorityWorkflow.ps1
# 三权工作流永久自检：默认只读检查静态契约，可选执行临时安装冒烟测试。
[CmdletBinding()]
param(
    [string]$BaselineRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$RunInstallSmoke
)

$ErrorActionPreference = 'Stop'
$BaselineRoot = (Resolve-Path -LiteralPath $BaselineRoot).Path
$script:BaselineRoot = $BaselineRoot
$script:Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$script:Failures = New-Object 'System.Collections.Generic.List[string]'
$script:CheckCount = 0

function Read-Utf8Strict([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "缺少自检文件：$Path"
    }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, $script:Utf8Strict)
}

function Add-Check([string]$Name, [bool]$Passed, [string]$FailureDetail) {
    $script:CheckCount += 1
    if ($Passed) {
        Write-Host "[通过] $Name" -ForegroundColor Green
        return
    }
    [void]$script:Failures.Add("$Name：$FailureDetail")
    Write-Host "[失败] $Name：$FailureDetail" -ForegroundColor Red
}

function Assert-Match([string]$Name, [string]$Text, [string]$Pattern, [string]$FailureDetail) {
    Add-Check $Name ([regex]::IsMatch($Text, $Pattern)) $FailureDetail
}

function Assert-NotMatch([string]$Name, [string]$Text, [string]$Pattern, [string]$FailureDetail) {
    Add-Check $Name (-not [regex]::IsMatch($Text, $Pattern)) $FailureDetail
}

function Assert-SetEqual([string]$Name, [object[]]$Actual, [object[]]$Expected) {
    $actualSet = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $expectedSet = @($Expected | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $diff = @(Compare-Object -ReferenceObject $expectedSet -DifferenceObject $actualSet)
    $detail = if ($diff.Count -eq 0) {
        ''
    } else {
        ($diff | ForEach-Object { "$($_.SideIndicator)$($_.InputObject)" }) -join '；'
    }
    Add-Check $Name ($diff.Count -eq 0) $detail
}

function Get-MarkdownSection([string]$Text, [string]$Heading) {
    $pattern = '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(?<Body>.*?)(?=^##\s+|\z)'
    $match = [regex]::Match($Text, $pattern)
    Add-Check "章节：$Heading" $match.Success "找不到二级标题 $Heading"
    if (-not $match.Success) {
        return ''
    }
    return $match.Groups['Body'].Value
}

function Get-StateRows([string]$Text) {
    $section = Get-MarkdownSection $Text '状态定义'
    $rows = @{}
    foreach ($line in ($section -split '\r?\n')) {
        $match = [regex]::Match(
            $line,
            '^\|\s*(?<State>[A-Z][A-Z0-9_]*)\s*\|\s*(?<Role>[^|]+?)\s*\|\s*(?<Pre>[^|]+?)\s*\|\s*(?<Required>[^|]+?)\s*\|\s*(?<Next>[^|]+?)\s*\|$'
        )
        if (-not $match.Success) {
            continue
        }
        $state = $match.Groups['State'].Value
        if ($rows.ContainsKey($state)) {
            Add-Check "状态唯一：$state" $false '状态表包含重复状态'
            continue
        }
        $rows[$state] = [pscustomobject]@{
            Role = $match.Groups['Role'].Value.Trim()
            Next = $match.Groups['Next'].Value.Trim()
        }
    }
    return $rows
}

function Get-FileHashMap([string]$Root) {
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $map = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File)) {
        $relative = $file.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        $map[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
    }
    return $map
}

function Test-RelativeMarkdownLinks([System.IO.FileInfo[]]$Files) {
    $broken = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in $Files) {
        $text = Read-Utf8Strict $file.FullName
        foreach ($match in [regex]::Matches($text, '(?<!!)\[[^\]]+\]\((?<Target>[^)]+)\)')) {
            $target = $match.Groups['Target'].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?|mailto):' -or $target.StartsWith('#') -or $target -match '\{\{') {
                continue
            }
            $pathPart = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) {
                continue
            }
            $pathPart = [Uri]::UnescapeDataString($pathPart).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $pathPart))
            if (-not (Test-Path -LiteralPath $resolved)) {
                $relativeFile = $file.FullName.Substring($script:BaselineRoot.Length).TrimStart([char[]]@('\', '/'))
                [void]$broken.Add("$relativeFile -> $target")
            }
        }
    }
    Add-Check 'LINKS' ($broken.Count -eq 0) ($broken -join '；')
}

$ExpectedModuleFiles = @(
    'workflows/three-authority-vibecoding/activation-rules.md'
    'workflows/three-authority-vibecoding/examples.md'
    'workflows/three-authority-vibecoding/handoff-contract.md'
    'workflows/three-authority-vibecoding/README.md'
    'workflows/three-authority-vibecoding/state-machine.md'
    'prompts/three-authority-vibecoding/approver-window.md'
    'prompts/three-authority-vibecoding/executor-window.md'
    'prompts/three-authority-vibecoding/README.md'
    'prompts/three-authority-vibecoding/tester-window.md'
    'templates/three-authority-vibecoding/approval-record.md'
    'templates/three-authority-vibecoding/execution-package.md'
    'templates/three-authority-vibecoding/execution-report.md'
    'templates/three-authority-vibecoding/independent-test-report.md'
    'templates/three-authority-vibecoding/README.md'
    'templates/three-authority-vibecoding/test-request.md'
)

$ModuleRoots = @(
    'workflows\three-authority-vibecoding'
    'prompts\three-authority-vibecoding'
    'templates\three-authority-vibecoding'
)

$actualModuleFiles = @()
foreach ($root in $ModuleRoots) {
    $rootPath = Join-Path $BaselineRoot $root
    if (Test-Path -LiteralPath $rootPath -PathType Container) {
        $actualModuleFiles += Get-ChildItem -LiteralPath $rootPath -Recurse -File | ForEach-Object {
            $_.FullName.Substring($BaselineRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        }
    }
}
Assert-SetEqual 'LAYOUT' $actualModuleFiles $ExpectedModuleFiles

$linkFiles = @(
    $ExpectedModuleFiles |
        ForEach-Object { Get-Item -LiteralPath (Join-Path $BaselineRoot $_.Replace('/', '\')) }
)
$linkFiles += Get-Item -LiteralPath (Join-Path $BaselineRoot 'README.md')
$linkFiles += Get-Item -LiteralPath (Join-Path $BaselineRoot 'USAGE.md')
Test-RelativeMarkdownLinks $linkFiles

$statePath = Join-Path $BaselineRoot 'workflows\three-authority-vibecoding\state-machine.md'
$handoffPath = Join-Path $BaselineRoot 'workflows\three-authority-vibecoding\handoff-contract.md'
$workflowReadmePath = Join-Path $BaselineRoot 'workflows\three-authority-vibecoding\README.md'
$examplesPath = Join-Path $BaselineRoot 'workflows\three-authority-vibecoding\examples.md'
$approverPath = Join-Path $BaselineRoot 'prompts\three-authority-vibecoding\approver-window.md'
$executorPath = Join-Path $BaselineRoot 'prompts\three-authority-vibecoding\executor-window.md'
$approvalRecordPath = Join-Path $BaselineRoot 'templates\three-authority-vibecoding\approval-record.md'
$usagePath = Join-Path $BaselineRoot 'USAGE.md'
$rootReadmePath = Join-Path $BaselineRoot 'README.md'

$stateText = Read-Utf8Strict $statePath
$handoffText = Read-Utf8Strict $handoffPath
$workflowReadme = Read-Utf8Strict $workflowReadmePath
$examplesText = Read-Utf8Strict $examplesPath
$approverText = Read-Utf8Strict $approverPath
$executorText = Read-Utf8Strict $executorPath
$approvalRecord = Read-Utf8Strict $approvalRecordPath
$usageText = Read-Utf8Strict $usagePath
$rootReadme = Read-Utf8Strict $rootReadmePath

$ExpectedStates = @(
    'PLAN_DRAFT', 'PLAN_APPROVED', 'IMPLEMENTING', 'CANDIDATE_READY',
    'APPROVE_TEST', 'TEST_REQUEST', 'PASS', 'CONDITIONAL_PASS', 'FAIL',
    'TEST_BLOCKED', 'SPEC_GAP', 'R1', 'R2', 'REPLAN', 'REJECT_SCOPE',
    'APPROVE_PUSH', 'APPROVE_RELEASE', 'OWNER_APPROVAL_REQUIRED', 'PUSHED', 'RELEASED'
)
$stateRows = Get-StateRows $stateText
Assert-SetEqual 'STATE_SET' @($stateRows.Keys) $ExpectedStates
Add-Check 'PUSH_NEXT' ($stateRows.ContainsKey('APPROVE_PUSH') -and $stateRows['APPROVE_PUSH'].Next -eq 'PUSHED、REPLAN') 'APPROVE_PUSH 下一状态必须精确为 PUSHED、REPLAN'
Add-Check 'RELEASE_NEXT' ($stateRows.ContainsKey('APPROVE_RELEASE') -and $stateRows['APPROVE_RELEASE'].Next -eq 'RELEASED、TEST_REQUEST、REPLAN') 'APPROVE_RELEASE 下一状态必须精确为 RELEASED、TEST_REQUEST、REPLAN'
Add-Check 'STATE_ROLE_TEST_REQUEST' ($stateRows['TEST_REQUEST'].Role -eq '审批') 'TEST_REQUEST 必须由审批窗口输出'
Add-Check 'STATE_ROLE_REPLAN' ($stateRows['REPLAN'].Role -eq '审批') 'REPLAN 必须由审批窗口输出'
Add-Check 'STATE_ROLE_PUSHED' ($stateRows['PUSHED'].Role -eq '执行') 'PUSHED 必须保持执行窗口成功结果'
Add-Check 'STATE_ROLE_RELEASED' ($stateRows['RELEASED'].Role -eq '执行或获授权发布者') 'RELEASED 必须保持执行或获授权发布者成功结果'

$stateFormat = Get-MarkdownSection $stateText '状态输出格式'
Assert-Match 'STATE_FORMAT_CANDIDATE' $stateFormat '(?m)^<STATE> <full-candidate-hash>\s*$' '候选阶段缺少完整候选哈希格式'
Assert-Match 'STATE_FORMAT_PRE_CANDIDATE' $stateFormat '(?m)^<STATE> <Task-ID> <Plan-Revision> <Base-Commit>\s*$' '候选产生前缺少任务三元组格式'
Assert-Match 'STATE_FORMAT_REPLAN' $stateFormat 'REPLAN 和 REJECT_SCOPE.*Candidate-Commit 已存在.*完整候选哈希' '没有明确 REPLAN 和 REJECT_SCOPE 的候选绑定规则'

$candidateReview = Get-MarkdownSection $approverText '审查候选提交'
$finalDecision = Get-MarkdownSection $approverText '最终裁决'
foreach ($section in @(
    @{ Name = '候选审查'; Text = $candidateReview }
    @{ Name = '最终裁决'; Text = $finalDecision }
)) {
    Assert-Match "APPROVER_REPLAN_$($section.Name)" $section.Text '(?m)^REPLAN <full-candidate-hash>\s*$' "$($section.Name)中的 REPLAN 未绑定完整候选哈希"
    Assert-Match "APPROVER_REJECT_$($section.Name)" $section.Text '(?m)^REJECT_SCOPE <full-candidate-hash>\s*$' "$($section.Name)中的 REJECT_SCOPE 未绑定完整候选哈希"
    Assert-NotMatch "APPROVER_NO_TRIPLE_$($section.Name)" $section.Text '(?m)^(?:REPLAN|REJECT_SCOPE) <Task-ID> <Plan-Revision> <Base-Commit>\s*$' "$($section.Name)仍使用无候选阶段任务三元组"
}

Assert-Match 'HANDOFF_PRE_CANDIDATE' $handoffText 'Candidate-Commit 尚不存在：[\s\S]*REPLAN <Task-ID> <Plan-Revision> <Base-Commit>' '交接契约缺少候选产生前示例'
Assert-Match 'HANDOFF_CANDIDATE' $handoffText 'Candidate-Commit 已存在：[\s\S]*REPLAN <full-candidate-hash>' '交接契约缺少候选产生后示例'
Assert-Match 'EXECUTOR_NO_APPROVAL_STATE' $executorText '不得自行输出 TEST_REQUEST、REPLAN 或 REJECT_SCOPE' '执行窗口仍可能越权输出审批状态'
Assert-Match 'PUSH_RECONCILE' $executorText '实际哈希等于 Candidate-Commit 才输出 PUSHED' '推送成功未绑定远端实际哈希'
Assert-Match 'RELEASE_RECONCILE' $executorText '全部目标摘要和健康检查均匹配才输出 RELEASED' '发布成功未绑定全部目标实际结果'
Assert-Match 'APPROVER_PUSH_FAILURE' $finalDecision '推送.*(?:失败|结果无法确认)[\s\S]*REPLAN <full-candidate-hash>' '审批窗口缺少推送失败裁决'
Assert-Match 'APPROVER_ARTIFACT_FAILURE' $finalDecision '发布前制品失效[\s\S]*TEST_REQUEST <full-candidate-hash>' '审批窗口缺少部署前制品失效裁决'
Assert-Match 'APPROVER_RELEASE_FAILURE' $finalDecision '发布已开始[\s\S]*(?:部分成功|结果未知)[\s\S]*REPLAN <full-candidate-hash>' '审批窗口缺少发布后失败裁决'

$contractText = @($stateText, $handoffText, $workflowReadme, $examplesText, $approverText, $executorText, $usageText) -join [Environment]::NewLine
foreach ($reason in @('REMOTE_DRIFT', 'PUSH_OUTCOME_UNKNOWN', 'ARTIFACT_INVALIDATED', 'RELEASE_PARTIAL', 'RELEASE_OUTCOME_UNKNOWN')) {
    Assert-Match "OUTCOME_$reason" $contractText ([regex]::Escape("reason=$reason")) "缺少原因码 $reason"
}
Assert-Match 'README_PUSH_FAILURE' $workflowReadme 'APPROVE_PUSH -> REPLAN' '工作流 README 缺少推送失败出口'
Assert-Match 'README_RELEASE_RETEST' $workflowReadme 'APPROVE_RELEASE -> TEST_REQUEST' '工作流 README 缺少部署前制品失效出口'
Assert-Match 'README_RELEASE_REPLAN' $workflowReadme 'APPROVE_RELEASE -> REPLAN' '工作流 README 缺少发布失败出口'
Assert-Match 'USAGE_PUSH_FAILURE' $usageText '旧 APPROVE_PUSH 不得重试' 'USAGE 缺少推送失败防重放说明'
Assert-Match 'USAGE_RELEASE_FAILURE' $usageText '发布已经开始后[\s\S]*不得重放旧 APPROVE_RELEASE' 'USAGE 缺少发布失败防重放说明'
Assert-Match 'APPROVAL_PUSH_RESULT' $approvalRecord '\{\{NOT_ATTEMPTED_PUSHED_FAILED_UNKNOWN_WITH_EVIDENCE\}\}' '审批模板不能表达推送失败或未知'
Assert-Match 'APPROVAL_RELEASE_RESULT' $approvalRecord '\{\{NOT_ATTEMPTED_RELEASED_FAILED_PARTIAL_UNKNOWN_WITH_EVIDENCE\}\}' '审批模板不能表达发布失败、部分成功或未知'
Assert-Match 'APPROVAL_STATE_HASH' $approvalRecord '\{\{STATE\}\} \{\{FULL_CANDIDATE_COMMIT\}\}' '审批模板状态行未绑定完整候选哈希'

Assert-Match 'README_ENTRY_LIST' $rootReadme 'Test-ThreeAuthorityWorkflow' '根 README 脚本清单未列出三权自检'
Assert-Match 'README_ENTRY_COMMAND' $rootReadme 'Test-ThreeAuthorityWorkflow\.ps1' '根 README 没有自检执行入口'

$version = (Read-Utf8Strict (Join-Path $BaselineRoot 'VERSION')).Trim()
$schema = Read-Utf8Strict (Join-Path $BaselineRoot 'schemas\project-rule-profile.example.json') | ConvertFrom-Json
$changelog = Read-Utf8Strict (Join-Path $BaselineRoot 'CHANGELOG.md')
Add-Check 'VERSION_FORMAT' ($version -match '^\d+\.\d+\.\d+$') 'VERSION 不是语义版本'
Add-Check 'VERSION_SYNC' ($schema.baselineVersion -eq $version) 'schema baselineVersion 与 VERSION 不一致'
Add-Check 'CHANGELOG_ENTRY' ($changelog.Contains('## 未发布') -or $changelog.Contains("## $version")) 'CHANGELOG 缺少当前版本或未发布章节'

$defaultReadingHits = New-Object 'System.Collections.Generic.List[string]'
foreach ($root in @('core', 'entry-templates', 'project-templates')) {
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $BaselineRoot $root) -Recurse -File)) {
        $text = Read-Utf8Strict $file.FullName
        if ($text -match '(?:approver|executor|tester)-window\.md') {
            [void]$defaultReadingHits.Add($file.FullName.Substring($BaselineRoot.Length).TrimStart([char[]]@('\', '/')))
        }
    }
}
Add-Check 'DEFAULT_OFF' ($defaultReadingHits.Count -eq 0) ($defaultReadingHits -join '；')

$expectedMappings = @(
    'workflows\three-authority-vibecoding'
    'prompts\three-authority-vibecoding'
    'templates\three-authority-vibecoding'
)
foreach ($scriptName in @('Install-AICodingRule.ps1', 'Audit-AICodingRule.ps1')) {
    $scriptText = Read-Utf8Strict (Join-Path $BaselineRoot "scripts\$scriptName")
    $mappingMatches = [regex]::Matches($scriptText, "(?m)^\s*Source\s*=\s*'(?<Source>[^']+)'")
    $actualMappings = @($mappingMatches | ForEach-Object { $_.Groups['Source'].Value })
    Assert-SetEqual "INSTALL_MAPPING_$scriptName" $actualMappings $expectedMappings
}

if ($RunInstallSmoke) {
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $sandbox = Join-Path $tempRoot ("aicoding-three-authority-" + [guid]::NewGuid().ToString('N'))
    $defaultProject = Join-Path $sandbox 'default'
    $optionalProject = Join-Path $sandbox 'optional'
    try {
        New-Item -ItemType Directory -Path $defaultProject, $optionalProject -Force | Out-Null
        $installScript = Join-Path $BaselineRoot 'scripts\Install-AICodingRule.ps1'
        $auditScript = Join-Path $BaselineRoot 'scripts\Audit-AICodingRule.ps1'

        $whatIfOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -ProjectPath $defaultProject -IncludeThreeAuthorityWorkflow -WhatIf 2>&1 | Out-String
        Add-Check 'SMOKE_WHATIF_EXIT' ($LASTEXITCODE -eq 0) $whatIfOutput
        Add-Check 'SMOKE_WHATIF_ZERO_WRITE' (@(Get-ChildItem -LiteralPath $defaultProject -Force).Count -eq 0) 'WhatIf 写入了目标目录'

        $defaultOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -ProjectPath $defaultProject 2>&1 | Out-String
        Add-Check 'SMOKE_DEFAULT_EXIT' ($LASTEXITCODE -eq 0) $defaultOutput
        $defaultOptionalRoots = @(
            'docs\ai\workflows\three-authority-vibecoding'
            'docs\ai\prompts\three-authority-vibecoding'
            'docs\ai\templates\three-authority-vibecoding'
        ) | Where-Object { Test-Path -LiteralPath (Join-Path $defaultProject $_) }
        Add-Check 'SMOKE_DEFAULT_OFF' ($defaultOptionalRoots.Count -eq 0) ($defaultOptionalRoots -join '；')

        $optionalOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -ProjectPath $optionalProject -IncludeThreeAuthorityWorkflow 2>&1 | Out-String
        Add-Check 'SMOKE_OPTIONAL_EXIT' ($LASTEXITCODE -eq 0) $optionalOutput
        $installedOptionalFiles = @()
        foreach ($root in $ModuleRoots) {
            $targetRoot = Join-Path $optionalProject (Join-Path 'docs\ai' $root)
            if (Test-Path -LiteralPath $targetRoot) {
                $installedOptionalFiles += Get-ChildItem -LiteralPath $targetRoot -Recurse -File
            }
        }
        Add-Check 'SMOKE_OPTIONAL_COUNT' ($installedOptionalFiles.Count -eq 15) "实际安装 $($installedOptionalFiles.Count) 个文件"

        $hashMismatches = New-Object 'System.Collections.Generic.List[string]'
        foreach ($relative in $ExpectedModuleFiles) {
            $source = Join-Path $BaselineRoot $relative.Replace('/', '\')
            $target = Join-Path $optionalProject (Join-Path 'docs\ai' $relative.Replace('/', '\'))
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                [void]$hashMismatches.Add("$relative 缺失")
                continue
            }
            if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash) {
                [void]$hashMismatches.Add("$relative 哈希不同")
            }
        }
        Add-Check 'SMOKE_OPTIONAL_HASH' ($hashMismatches.Count -eq 0) ($hashMismatches -join '；')

        $beforeMap = Get-FileHashMap $optionalProject
        $repeatOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -ProjectPath $optionalProject -IncludeThreeAuthorityWorkflow 2>&1 | Out-String
        Add-Check 'SMOKE_REPEAT_EXIT' ($LASTEXITCODE -eq 0) $repeatOutput
        $afterMap = Get-FileHashMap $optionalProject
        $beforeEntries = @($beforeMap.Keys | Sort-Object | ForEach-Object { "$_=$($beforeMap[$_])" })
        $afterEntries = @($afterMap.Keys | Sort-Object | ForEach-Object { "$_=$($afterMap[$_])" })
        Assert-SetEqual 'SMOKE_REPEAT_DIGEST' $afterEntries $beforeEntries

        $auditOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -ProjectPath $optionalProject 2>&1 | Out-String
        Add-Check 'SMOKE_AUDIT_EXIT' ($LASTEXITCODE -eq 0) $auditOutput
        Assert-Match 'SMOKE_AUDIT_WARN_ZERO' $auditOutput 'WARN[：:]\s*0' 'Audit 不是 WARN 0'
    } finally {
        $resolvedSandbox = [System.IO.Path]::GetFullPath($sandbox)
        if ($resolvedSandbox.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedSandbox)) {
            Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force
        }
    }
}

Write-Host ''
if ($Failures.Count -gt 0) {
    Write-Host "三权工作流自检失败：$($Failures.Count)/$CheckCount" -ForegroundColor Red
    $Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "三权工作流自检通过：$CheckCount 项。" -ForegroundColor Green
exit 0
~~~

- [ ] **步骤 2：转换为与现有脚本一致的 UTF-8 BOM**

使用机械编码转换，不改变脚本文本：

~~~powershell
$path = Resolve-Path .\scripts\Test-ThreeAuthorityWorkflow.ps1
$utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$content = [System.IO.File]::ReadAllText($path, $utf8NoBom)
[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
~~~

预期：文件前三个字节为 239、187、191。

- [ ] **步骤 3：验证脚本语法**

运行：

~~~powershell
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\scripts\Test-ThreeAuthorityWorkflow.ps1),
    [ref]$tokens,
    [ref]$errors
)
if ($errors.Count -gt 0) {
    $errors | Format-List
    exit 1
}
~~~

预期：退出码 0，无解析错误。

- [ ] **步骤 4：运行 RED 验证**

运行：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
~~~

预期：退出码 1；至少 PUSH_NEXT、RELEASE_NEXT、APPROVER_REPLAN_候选审查、APPROVER_REPLAN_最终裁决、README_PUSH_FAILURE、README_ENTRY_LIST 失败。不得通过放宽断言消除失败。

## 任务 2：修复唯一状态机与交接契约

**文件：**

- 修改：workflows/three-authority-vibecoding/state-machine.md:7
- 修改：workflows/three-authority-vibecoding/state-machine.md:42
- 修改：workflows/three-authority-vibecoding/state-machine.md:63
- 修改：workflows/three-authority-vibecoding/handoff-contract.md:69
- 修改：workflows/three-authority-vibecoding/handoff-contract.md:103

- [ ] **步骤 1：补齐状态机主路径和状态表**

主路径改为：

~~~text
PASS | CONDITIONAL_PASS
-> APPROVE_PUSH -> PUSHED | REPLAN
-> OWNER_APPROVAL_REQUIRED（L3 生产发布）
-> APPROVE_RELEASE -> RELEASED | TEST_REQUEST | REPLAN
~~~

状态表两行的允许下一状态精确改为：

~~~text
APPROVE_PUSH：PUSHED、REPLAN
APPROVE_RELEASE：RELEASED、TEST_REQUEST、REPLAN
~~~

- [ ] **步骤 2：写明批准动作失败的输出权责**

在状态表后新增：

~~~text
批准动作失败时，执行窗口或获授权发布者只回传实际执行证据和原因码，不得自行输出 TEST_REQUEST、REPLAN 或 REJECT_SCOPE；下一状态仍由审批窗口裁决。APPROVE_RELEASE 只有在尚未产生部署副作用、Candidate-Commit 未变化且制品需要重新生成或验证时才能回到 TEST_REQUEST；发布已开始、部分成功或结果无法确认时必须 REPLAN。
~~~

在状态输出格式末尾新增：

~~~text
REPLAN 和 REJECT_SCOPE 同样遵守上述绑定规则：Candidate-Commit 已存在时必须绑定完整候选哈希，不得退回任务三元组；Task-ID、Plan-Revision 和 Base-Commit 继续保留在结构化交接信封中。
~~~

- [ ] **步骤 3：修复推送对账契约**

将 handoff-contract.md 的推送失败条款替换为：

~~~text
- 本工作流禁止强制推送。远端偏离 Expected-Remote-Hash 或普通推送失败时，执行窗口必须停止并重新读取精确 Push-Ref：实际哈希等于 Candidate-Commit 才可输出 PUSHED；仍等于 Expected-Remote-Hash、出现其他哈希或无法读取时，只回传预期值、实际值或 UNKNOWN、命令结果和原因码，由审批窗口输出 REPLAN。不得使用旧 APPROVE_PUSH 重试，也不得改用强制推送或删除远端引用。
~~~

- [ ] **步骤 4：修复发布前后失败契约**

将原制品失效条款替换为：

~~~text
- 发布前发现制品缺失、重建或摘要变化，且尚未产生部署副作用、Candidate-Commit 未变化时，旧测试、APPROVE_RELEASE 和 Owner-Evidence 立即失效；执行窗口只回传证据，由审批窗口重新输出 TEST_REQUEST。
- 发布动作已经开始后，如失败、部分成功或结果无法确认，执行窗口不得输出 RELEASED 或自行重新测试；必须回传各目标实际摘要、健康状态、已执行步骤和回滚结果，由审批窗口输出 REPLAN。环境收敛并重新批准前不得重放旧 APPROVE_RELEASE。
~~~

- [ ] **步骤 5：补齐候选前后原因码示例**

将原因码代码块替换为：

~~~text
TEST_BLOCKED <full-hash> reason=BLOCKED_ENVIRONMENT

Candidate-Commit 尚不存在：
REPLAN <Task-ID> <Plan-Revision> <Base-Commit> reason=BASE_DRIFT
REJECT_SCOPE <Task-ID> <Plan-Revision> <Base-Commit> reason=SCOPE_CONFLICT

Candidate-Commit 已存在：
REPLAN <full-candidate-hash> reason=REMOTE_DRIFT
REPLAN <full-candidate-hash> reason=PUSH_OUTCOME_UNKNOWN
TEST_REQUEST <full-candidate-hash> reason=ARTIFACT_INVALIDATED
REPLAN <full-candidate-hash> reason=RELEASE_PARTIAL
REPLAN <full-candidate-hash> reason=RELEASE_OUTCOME_UNKNOWN
REJECT_SCOPE <full-candidate-hash> reason=SCOPE_CONFLICT
~~~

- [ ] **步骤 6：重跑静态自检观察剩余 RED**

运行任务 1 步骤 4 的命令。

预期：PUSH_NEXT、RELEASE_NEXT、STATE_FORMAT、HANDOFF 两阶段检查通过；角色 Prompt、示例、README、USAGE 和脚本入口相关检查仍失败。

## 任务 3：统一角色提示词、模板、示例和使用入口

**文件：**

- 修改：prompts/three-authority-vibecoding/approver-window.md:63
- 修改：prompts/three-authority-vibecoding/approver-window.md:99
- 修改：prompts/three-authority-vibecoding/executor-window.md:89
- 修改：templates/three-authority-vibecoding/approval-record.md:58
- 修改：workflows/three-authority-vibecoding/examples.md:99
- 修改：workflows/three-authority-vibecoding/README.md:39
- 修改：USAGE.md:650
- 修改：USAGE.md:672
- 修改：USAGE.md:690
- 修改：USAGE.md:714
- 修改：README.md:14
- 修改：README.md:44
- 修改：CHANGELOG.md:1

- [ ] **步骤 1：统一审批窗口候选状态格式**

在“审查候选提交”和“最终裁决”两个代码块中，都把两行改为：

~~~text
REPLAN <full-candidate-hash>
REJECT_SCOPE <full-candidate-hash>
~~~

- [ ] **步骤 2：补齐审批窗口失败裁决**

用下列文本替换推送裁决段，并在发布裁决段后追加第二段：

~~~text
APPROVE_PUSH 的同一交接信封必须给出 Push-Remote、Push-Ref、Push-Mode=fast-forward-only 和 Expected-Remote-Hash；本工作流不批准强制推送。执行窗口回传远端漂移、推送失败或结果无法确认的证据后，由你核对精确 Push-Ref 并输出 REPLAN <full-candidate-hash>；旧 APPROVE_PUSH 不得重放。

执行窗口只能回传推送或发布动作的事实、实际状态和原因码，不得自行输出审批状态。发布前制品失效且尚未产生部署副作用、Candidate-Commit 未变化时，你应输出 TEST_REQUEST <full-candidate-hash>；发布已开始后发生失败、部分成功、结果未知，或部署策略、目标环境、发布前提失效时，你应输出 REPLAN <full-candidate-hash>。重新测试后必须重新取得发布批准；L3 或项目策略要求 Owner 时，还必须重新取得绑定同一制品摘要和环境的 Owner-Evidence。
~~~

- [ ] **步骤 3：限制执行窗口只回传事实**

在批准动作预检段追加：

~~~text
停止后必须回传预期值、实际值、命令结果、工作区、远端或目标环境状态和 reason code，等待审批窗口裁决。执行窗口不得自行输出 TEST_REQUEST、REPLAN 或 REJECT_SCOPE。
~~~

把推送失败和发布失败段分别收敛为：

~~~text
推送命令失败或结果不确定时必须重新读取精确 Push-Ref：实际哈希等于 Candidate-Commit 才输出 PUSHED；仍等于 Expected-Remote-Hash、为其他哈希或无法读取时，回传 Actual-Remote-Hash（无法确认写 UNKNOWN）、命令退出码和证据，等待审批窗口输出 REPLAN。不得使用旧批准重试。

部署前发现制品缺失或摘要不符时停止并回传证据；尚未产生部署副作用时，由审批窗口决定重新 TEST_REQUEST。部署已经开始后，只有全部目标摘要和健康检查均匹配才输出 RELEASED；失败、部分成功或结果未知时，必须记录各目标实际摘要、健康状态、已执行步骤和回滚结果，等待审批窗口输出 REPLAN。任一批准不隐含另一批准，执行窗口不得自行裁决。
~~~

- [ ] **步骤 4：让审批记录表达不确定结果**

只替换 Audit 中两行，State 行保持不变：

~~~text
- Pushed-State: {{NOT_ATTEMPTED_PUSHED_FAILED_UNKNOWN_WITH_EVIDENCE}}
- Released-State: {{NOT_ATTEMPTED_RELEASED_FAILED_PARTIAL_UNKNOWN_WITH_EVIDENCE}}
~~~

- [ ] **步骤 5：新增两个完整失败示例**

在 examples.md 末尾新增：

~~~~markdown
## 6. 推送失败只回传证据，由审批窗口裁决

执行窗口发现远端漂移或推送结果无法确认时，只回传 Expected-Remote-Hash、Actual-Remote-Hash、命令结果和 reason code，不创建 PUSH_FAILED 状态。审批窗口核验后输出：

~~~text
Expected-Remote-Hash: 4444444444444444444444444444444444444444
Actual-Remote-Hash: 5555555555555555555555555555555555555555
Push-Result: UNKNOWN
REPLAN ffffffffffffffffffffffffffffffffffffffff reason=REMOTE_DRIFT
REPLAN ffffffffffffffffffffffffffffffffffffffff reason=PUSH_OUTCOME_UNKNOWN
~~~

旧 APPROVE_PUSH 不得重放。只有远端实际哈希等于 ffffffffffffffffffffffffffffffffffffffff 时，执行窗口才能输出 PUSHED。

## 7. 发布失败按是否产生部署副作用分流

部署前制品失效且 Candidate-Commit 未变化：

~~~text
Artifact-Digest: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Artifact-Actual-Digest: sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
TEST_REQUEST ffffffffffffffffffffffffffffffffffffffff reason=ARTIFACT_INVALIDATED
~~~

部署已经开始后发生部分成功或结果未知，执行窗口只回传实际摘要、健康状态、已执行步骤和回滚证据，由审批窗口输出：

~~~text
Release-Result: PARTIAL
REPLAN ffffffffffffffffffffffffffffffffffffffff reason=RELEASE_PARTIAL
REPLAN ffffffffffffffffffffffffffffffffffffffff reason=RELEASE_OUTCOME_UNKNOWN
~~~

旧 APPROVE_RELEASE 和已失效的 Owner-Evidence 均不得重放。
~~~~

计划外层用四个波浪号展示完整片段；写入 examples.md 时保留内部三个波浪号代码围栏。

- [ ] **步骤 6：补全工作流 README 失败分支**

在标准流程失败分支新增：

~~~text
APPROVE_PUSH -> REPLAN（远端漂移、推送未生效或结果无法确认）
APPROVE_RELEASE -> TEST_REQUEST（部署前制品失效、候选未变化）
APPROVE_RELEASE -> REPLAN（发布已开始后失败、部分成功、结果未知，或发布前提失效）
~~~

在状态机导航句后新增：

~~~text
批准动作失败时，执行窗口或获授权发布者只回传实际证据和原因码；TEST_REQUEST、REPLAN、REJECT_SCOPE 仍由审批窗口输出。只有远端实际哈希等于候选提交才能输出 PUSHED，只有已批准制品在全部目标完成部署并通过摘要与健康核验才能输出 RELEASED。
~~~

- [ ] **步骤 7：统一 USAGE 候选格式与失败路径**

在 10.5 候选审查指令后新增：

~~~text
Candidate-Commit 已存在，上述 APPROVE_TEST、R1、R2、REPLAN 和 REJECT_SCOPE 状态行都必须绑定同一完整 Candidate-Commit；Task-ID、Plan-Revision 和 Base-Commit 继续保留在交接信封字段中。
~~~

把 10.7 的 REPLAN 和 REJECT_SCOPE 项替换为：

~~~text
- REPLAN <完整候选提交哈希>：候选阶段的需求、范围、合同、基线或验收矩阵必须重写；
- REJECT_SCOPE <完整候选提交哈希>：候选阶段发现请求越权或不属于当前任务。
~~~

在 10.8 推送段和发布段分别新增：

~~~text
远端漂移、普通推送失败或推送结果无法核验时，执行窗口只回传预期/实际远端哈希、命令结果和原因码，不自行输出 REPLAN；审批窗口核验证据后输出 REPLAN <完整提交哈希>。旧 APPROVE_PUSH 不得重试。

部署前制品缺失、重建或摘要变化且 Candidate-Commit 未变化时，执行窗口只回传证据，审批窗口重新输出 TEST_REQUEST <完整提交哈希>，并重新完成独立测试和适用的人工批准。发布已经开始后，如失败、部分成功或结果未知，执行窗口必须回传各目标实际状态和回滚证据，由审批窗口输出 REPLAN <完整提交哈希>；环境收敛和重新批准前不得重放旧 APPROVE_RELEASE。
~~~

在 11.1 快速体检的 Audit 命令前新增：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
~~~

- [ ] **步骤 8：增加根 README 自检入口**

目录职责脚本行改为：

~~~text
scripts/               Install（安装）/ Audit（项目静态审计）/ Compare（基线比较）/ Test-ThreeAuthorityWorkflow（三权契约自检）
~~~

快速使用代码块末尾新增：

~~~powershell
# 6. 维护者：检查三权工作流状态契约；加 -RunInstallSmoke 执行临时安装冒烟
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
~~~

- [ ] **步骤 9：增加未发布变更记录**

在 CHANGELOG 标题后新增：

~~~text
## 未发布

- 修复 APPROVE_PUSH 和 APPROVE_RELEASE 缺少合法失败出口的问题。
- 候选产生后的 REPLAN、REJECT_SCOPE 统一绑定完整 Candidate-Commit。
- 明确推送与发布结果未知、部分成功时由执行窗口回传证据、审批窗口裁决，旧批准不得重放。
- 增加三权工作流永久静态自检和临时安装冒烟入口。
~~~

- [ ] **步骤 10：运行 GREEN 静态验证**

运行：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
~~~

预期：退出码 0，末行显示“三权工作流自检通过”。

## 任务 4：完成上游冒烟、边界验证和原子实现提交

**文件：**

- 验证：scripts 下全部 PowerShell 文件。
- 验证：任务 1 至任务 3 的全部变更。

- [ ] **步骤 1：运行临时安装冒烟**

运行：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1 -RunInstallSmoke
~~~

预期：WhatIf 零写入；默认安装无三权目录；可选安装 15 个文件逐文件 SHA-256 一致；重复安装摘要不变；Audit 为 WARN 0；退出码 0；临时目录被清理。

- [ ] **步骤 2：解析全部 PowerShell 脚本**

运行：

~~~powershell
$bad = @()
Get-ChildItem .\scripts\*.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -gt 0) {
        $bad += $errors
    }
}
if ($bad.Count -gt 0) {
    $bad | Format-List
    exit 1
}
~~~

预期：退出码 0。

- [ ] **步骤 3：验证版本和禁止修改边界**

运行：

~~~powershell
$base = 'fecc114e9203adb86eb25fefa0d5eb4631f804b5'
if ((Get-Content -Raw .\VERSION).Trim() -ne '0.2.0') {
    throw 'VERSION 被误改'
}
$profile = Get-Content -Raw .\schemas\project-rule-profile.example.json | ConvertFrom-Json
if ($profile.baselineVersion -ne '0.2.0') {
    throw 'schema 基线版本被误改'
}
$forbidden = git diff --name-only $base -- VERSION schemas core scripts/Install-AICodingRule.ps1 scripts/Audit-AICodingRule.ps1
if ($forbidden) {
    throw "出现禁止修改：$($forbidden -join '；')"
}
git diff --check $base
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
~~~

预期：VERSION 与 schema 均为 0.2.0，禁止修改集合为空，diff 检查通过。

- [ ] **步骤 4：审查实际文件集合**

运行：

~~~powershell
git diff --name-status fecc114e9203adb86eb25fefa0d5eb4631f804b5
git status --short
~~~

预期：只出现文件结构章节声明的实现文件和未提交计划文档；没有项目外文件、缓存、临时目录或无关改动。

- [ ] **步骤 5：提交上游原子实现**

只暂存实现文件，计划文档已在前置提交中，不把交接快照放入本提交：

~~~powershell
git add -- README.md USAGE.md CHANGELOG.md scripts/Test-ThreeAuthorityWorkflow.ps1 workflows/three-authority-vibecoding/state-machine.md workflows/three-authority-vibecoding/handoff-contract.md workflows/three-authority-vibecoding/README.md workflows/three-authority-vibecoding/examples.md prompts/three-authority-vibecoding/approver-window.md prompts/three-authority-vibecoding/executor-window.md templates/three-authority-vibecoding/approval-record.md
git diff --cached --check
git commit -m "修复：统一三权状态契约并增加永久自检"
git status --short
~~~

预期：提交成功；工作区为空；记录：

~~~powershell
$implementationCommit = git rev-parse HEAD
git show --check --oneline $implementationCommit
~~~

实现提交不得 amend；交接快照必须引用这个完整哈希。

## 任务 5：原位更新当前交接快照

**文件：**

- 修改：reports/P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1-HANDOFF.md

- [ ] **步骤 1：取得不可变实现证据锚**

运行：

~~~powershell
$implementationCommit = git rev-parse HEAD
git rev-parse --verify "$implementationCommit^{commit}"
~~~

预期：两次输出逐字符一致的完整提交哈希。

- [ ] **步骤 2：原位替换陈旧结论**

使用 apply_patch 原位更新同一 Task-ID 报告，不追加互相矛盾的旧结论：

- 当前分支改为修复分支实际名称。
- 增加“状态契约修复证据锚”，值为步骤 1 的完整 implementationCommit。
- 实现状态改为“状态失败出口、候选绑定和动作对账风险已修复；以验证结果为准”。
- 删除“没有已知 Critical 或 Important 实现缺口”的陈旧绝对结论。
- 冻结决定增加 APPROVE_PUSH 到 REPLAN、APPROVE_RELEASE 到 TEST_REQUEST/REPLAN，以及执行回报、审批裁决。
- 已执行验证改为本轮真实输出：静态自检、安装冒烟、15 文件、链接、PowerShell 解析、WARN 0、版本保持 0.2.0。
- 残余风险保留“具体制品仓库技术实现由项目执行包冻结”，删除“仓库没有自带自动化测试”的陈旧结论。
- 下一窗口动作改为优先运行 Test-ThreeAuthorityWorkflow.ps1；明确远端未推送时的真实状态。

不得把报告提交自身哈希写成证据锚。

- [ ] **步骤 3：验证并提交交接快照**

运行：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
git diff --check $implementationCommit
git diff --name-only $implementationCommit
~~~

预期：自检通过；差异只有交接报告。

提交：

~~~powershell
git add -- reports/P1-AICODING-RULE-THREE-AUTHORITY-WORKFLOW-1-HANDOFF.md
git commit -m "文档：更新三权状态契约修复交接证据"
git status --short
~~~

预期：提交成功，工作区为空。

## 任务 6：本地集成上游修复

**文件：**

- 仓库：I:\project\AICoding-RULE
- 修复工作树：I:\project\AICoding-RULE-worktree-state-contract

- [ ] **步骤 1：在修复工作树做最终复验**

运行静态自检、安装冒烟、git diff --check 和 git status --short。

预期：全部通过，工作区为空。

- [ ] **步骤 2：确认主仓库仍在冻结基线**

在 I:\project\AICoding-RULE 运行：

~~~powershell
git status --short
git branch --show-current
git rev-parse HEAD
git fetch origin
git merge --ff-only origin/master
~~~

预期：master、工作区为空；若 HEAD 或远端在任务期间变化，停止合并并重新核对，不强制覆盖。

- [ ] **步骤 3：本地快进合并**

在主仓库运行：

~~~powershell
git merge --ff-only fix/three-authority-state-contract
~~~

预期：仅快进成功。

- [ ] **步骤 4：推送上游 master**

用户已明确授权完成提交并推送。运行：

~~~powershell
git push origin master
git rev-parse HEAD
git rev-parse origin/master
~~~

预期：推送成功，HEAD 与 origin/master 逐字符一致。

## 任务 7：只同步实际变化的分发文件到 gaozong

**文件：**

- 来源：上游 implementationCommit 中实际变化的 workflows、prompts、templates 文件。
- 目标：I:\work\gaozong 的 docs/ai 对应路径。

- [ ] **步骤 1：重新阅读 gaozong 必读规则并冻结基线**

按顺序读取：

1. docs/ai/01_READING_RULES.md
2. docs/ai/05_PROJECT_CONTEXT.md
3. docs/ai/02_EXECUTION_RULES.md
4. docs/ai/03_TESTING_RULES.md
5. docs/ai/04_OUTPUT_RULES.md

回答读取门的八个问题并记录 gaozong master 完整哈希。确认工作区为空；有并行修改则停止。

- [ ] **步骤 2：创建 gaozong 隔离工作树**

使用 using-git-worktrees 流程创建分支 fix/three-authority-state-contract-sync。不得在主工作区直接施工。

- [ ] **步骤 3：从实现提交自动提取分发清单**

在上游仓库运行：

~~~powershell
$implementationCommit = git log --format='%H' --grep='^修复：统一三权状态契约并增加永久自检$' -1
$changed = git diff-tree --no-commit-id --name-only -r $implementationCommit
$distributed = @(
    $changed | Where-Object {
        $_ -like 'workflows/three-authority-vibecoding/*' -or
        $_ -like 'prompts/three-authority-vibecoding/*' -or
        $_ -like 'templates/three-authority-vibecoding/*'
    }
)
if ($distributed.Count -eq 0) {
    throw '实现提交没有可同步的三权分发文件'
}
~~~

明确排除 README.md、USAGE.md、CHANGELOG.md、VERSION、schemas、scripts、reports、core、project-templates、.aicoding-rule.json，以及三权目录内未在实现提交中变化的文件。

- [ ] **步骤 4：逐文件映射并复制**

对 distributed 中每个文件按下列精确映射同步：

~~~text
workflows/three-authority-vibecoding/ -> docs/ai/workflows/three-authority-vibecoding/
prompts/three-authority-vibecoding/   -> docs/ai/prompts/three-authority-vibecoding/
templates/three-authority-vibecoding/ -> docs/ai/templates/three-authority-vibecoding/
~~~

文件内容必须来自 implementationCommit 对应工作树；使用 apply_patch 逐文件更新目标，不用 Copy-Item 或其他命令绕过差异审阅。不运行 Install 覆盖已有模块，不同步整个目录。

- [ ] **步骤 5：核对逐文件 SHA-256 和差异集合**

对 distributed 每项计算来源与目标 SHA-256，任何一项不同立即失败。再运行：

~~~powershell
git diff --check
git diff --name-status
~~~

预期：目标差异集合精确等于映射后的 distributed，没有额外文件。

- [ ] **步骤 6：运行 gaozong 项目验证**

从已合并的上游仓库运行：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Audit-AICodingRule.ps1 -ProjectPath I:\work\gaozong-worktree-state-contract-sync
~~~

另运行目标模块 Markdown 相对链接只读检查。

预期：上游静态自检通过；Audit WARN 0；模块保持“已安装、默认关闭、按风险显式启用”；相对链接 0 个失效。

- [ ] **步骤 7：提交 gaozong 同步**

只暂存映射清单：

~~~powershell
git add -- docs/ai/workflows/three-authority-vibecoding docs/ai/prompts/three-authority-vibecoding docs/ai/templates/three-authority-vibecoding
git diff --cached --check
git commit -m "文档：同步三权状态契约修复"
git status --short
~~~

预期：提交成功，工作区为空。提交正文不记录自身哈希；最终总结单独报告上游 implementationCommit 和下游同步提交哈希。

## 任务 8：本地集成 gaozong 并完成最终核验

**文件：**

- 仓库：I:\work\gaozong
- 同步工作树：I:\work\gaozong-worktree-state-contract-sync

- [ ] **步骤 1：复验同步候选**

重复任务 7 的 SHA-256、相对链接、Audit、git diff --check 和工作区检查。

预期：全部通过。

- [ ] **步骤 2：本地快进合并 gaozong**

在 I:\work\gaozong 主仓库确认 master、工作区为空、HEAD 仍等于冻结基线后运行：

~~~powershell
git merge --ff-only fix/three-authority-state-contract-sync
~~~

预期：仅快进成功。

- [ ] **步骤 3：推送 gaozong master**

运行：

~~~powershell
git push origin master
git rev-parse HEAD
git rev-parse origin/master
~~~

预期：推送成功，HEAD 与 origin/master 逐字符一致。

- [ ] **步骤 4：在两个主仓库执行最终检查**

上游：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ThreeAuthorityWorkflow.ps1 -RunInstallSmoke
git status --short
git log -5 --oneline
~~~

gaozong：

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File I:\project\AICoding-RULE\scripts\Audit-AICodingRule.ps1 -ProjectPath I:\work\gaozong
git status --short
git log -3 --oneline
~~~

预期：上游自检和冒烟通过；gaozong Audit WARN 0；两个 master 工作区均为空；VERSION 和 schema 仍为 0.2.0；两个 origin/master 均等于本地 master。

- [ ] **步骤 5：清理隔离工作树和已合并临时分支**

仅在确认两个 master 都包含对应提交、验证全部通过后，使用 finishing-a-development-branch 流程安全清理两个隔离工作树与已合并分支。不得删除未合并或含未提交修改的工作树。

## 自审清单

- 设计中的两类根因分别由任务 2、任务 3 覆盖。
- 推送结果未知、发布部分成功和旧批准重放由交接契约、角色提示词、示例和自检共同覆盖。
- 执行窗口没有获得 TEST_REQUEST、REPLAN、REJECT_SCOPE 的输出权。
- 既有 20 个状态和 15 个模块文件集合不变。
- VERSION、schema、core、安装器和 Audit 明确不改。
- 全局版本误报风险通过保持 0.2.0 消除。
- 交接报告通过独立后续提交记录实现证据锚，避免自引用。
- gaozong 只同步实现提交实际变化的分发文件，不运行安装器覆盖。
- 所有写入步骤都有对应 RED、GREEN、冒烟、哈希、链接或差异集合验证。
- 计划中没有未定义实现、待补内容或依赖新框架。
