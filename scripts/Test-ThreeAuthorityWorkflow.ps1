# Test-ThreeAuthorityWorkflow.ps1
# 三权工作流永久自检：默认只读检查静态契约，可选执行临时安装冒烟测试。
[CmdletBinding()]
param(
    [string]$BaselineRoot,
    [switch]$RunInstallSmoke
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object 'System.Collections.Generic.List[string]'
$script:CheckCount = 0
$script:Utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Read-Utf8([string]$RelativePath) {
    $path = Join-Path $script:BaselineRoot $RelativePath
    try {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Check "读取文件：$RelativePath" $false "缺少自检文件：$RelativePath"
            return $null
        }
        return [System.IO.File]::ReadAllText($path, $script:Utf8)
    } catch {
        Add-Check "读取文件：$RelativePath" $false "读取失败：$($_.Exception.Message)"
        return $null
    }
}

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail) {
    $script:CheckCount++
    if ($Passed) {
        Write-Host "[通过] $Name" -ForegroundColor Green
        return
    }
    [void]$script:Failures.Add("$Name：$Detail")
    Write-Host "[失败] $Name：$Detail" -ForegroundColor Red
}

function Complete-Check {
    Write-Host "`n三权工作流自检：$($script:CheckCount) 项检查，失败 $($script:Failures.Count) 项。"
    if ($script:Failures.Count -gt 0) {
        Write-Host '失败摘要：' -ForegroundColor Red
        $script:Failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host '三权工作流自检通过。' -ForegroundColor Green
    exit 0
}

if ([string]::IsNullOrWhiteSpace($BaselineRoot)) {
    $BaselineRoot = Split-Path -Parent $PSScriptRoot
}
try {
    $BaselineRoot = (Resolve-Path -LiteralPath $BaselineRoot -ErrorAction Stop).Path
} catch {
    Add-Check '基线目录' $false "路径无效或不可访问：$BaselineRoot"
    Complete-Check
}
if (-not (Test-Path -LiteralPath $BaselineRoot -PathType Container)) {
    Add-Check '基线目录' $false "必须是目录：$BaselineRoot"
    Complete-Check
}
$script:BaselineRoot = $BaselineRoot

function Assert-Match([string]$Name, [string]$Text, [string]$Pattern, [string]$Detail) {
    if ($null -eq $Text) {
        Add-Check $Name $false $Detail
        return
    }
    Add-Check $Name ([regex]::IsMatch($Text, $Pattern)) $Detail
}

function Assert-NotMatch([string]$Name, [string]$Text, [string]$Pattern, [string]$Detail) {
    if ($null -eq $Text) {
        Add-Check $Name $false $Detail
        return
    }
    Add-Check $Name (-not [regex]::IsMatch($Text, $Pattern)) $Detail
}

function Assert-SetEqual([string]$Name, [object[]]$Actual, [object[]]$Expected) {
    $actualSet = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $expectedSet = @($Expected | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $diff = @(Compare-Object -ReferenceObject $expectedSet -DifferenceObject $actualSet)
    $detail = if ($diff.Count -eq 0) { '' } else { ($diff | ForEach-Object { "$($_.SideIndicator)$($_.InputObject)" }) -join '；' }
    Add-Check $Name ($diff.Count -eq 0) $detail
}

function Get-MarkdownSection([string]$Text, [string]$Heading) {
    if ($null -eq $Text) {
        Add-Check "章节：$Heading" $false "所属文件不可读取，无法定位二级标题 $Heading"
        return ''
    }
    $match = [regex]::Match($Text, '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(?<Body>.*?)(?=^##\s+|\z)')
    Add-Check "章节：$Heading" $match.Success "找不到二级标题 $Heading"
    if ($match.Success) { return $match.Groups['Body'].Value }
    return ''
}

function Get-TreeHash([string]$Root) {
    try {
        $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
        $items = New-Object 'System.Collections.Generic.List[string]'
        [void]$items.Add('D|')
        foreach ($item in @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop)) {
            $relative = $item.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            if ($item.PSIsContainer) {
                [void]$items.Add("D|$relative")
            } else {
                [void]$items.Add("F|$relative|$((Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash)")
            }
        }
        $snapshot = @($items | Sort-Object) -join "`n"
        $stream = New-Object System.IO.MemoryStream(,[System.Text.Encoding]::UTF8.GetBytes($snapshot))
        try {
            $stream.Position = 0
            return (Get-FileHash -Algorithm SHA256 -InputStream $stream).Hash
        } finally {
            $stream.Dispose()
        }
    } catch {
        Add-Check "目录哈希：$Root" $false "计算失败：$($_.Exception.Message)"
        return $null
    }
}

function Test-RelativeMarkdownLinks([string[]]$RelativePaths) {
    $broken = New-Object 'System.Collections.Generic.List[string]'
    foreach ($relativePath in $RelativePaths) {
        $path = Join-Path $script:BaselineRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            [void]$broken.Add("$relativePath（文件不存在）")
            continue
        }
        try { $text = [System.IO.File]::ReadAllText($path, $script:Utf8) } catch {
            [void]$broken.Add("$relativePath（读取失败：$($_.Exception.Message)）")
            continue
        }
        foreach ($match in [regex]::Matches($text, '!?\[[^\]]*\]\((?<Target>[^)]+)\)')) {
            $target = $match.Groups['Target'].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?|mailto):' -or $target.StartsWith('#') -or $target -match '\{\{') { continue }
            $pathPart = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            try {
                $resolved = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $path) ([Uri]::UnescapeDataString($pathPart).Replace('/', [System.IO.Path]::DirectorySeparatorChar))))
                if (-not (Test-Path -LiteralPath $resolved)) { [void]$broken.Add("$relativePath -> $target") }
            } catch { [void]$broken.Add("$relativePath -> $target（路径格式无效）") }
        }
        foreach ($match in [regex]::Matches($text, '(?m)^\s*\[[^\]]+\]:\s+(?<Target><[^>]+>|[^\s]+)')) {
            $target = $match.Groups['Target'].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?|mailto):' -or $target.StartsWith('#') -or $target -match '\{\{') { continue }
            $pathPart = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            try {
                $resolved = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $path) ([Uri]::UnescapeDataString($pathPart).Replace('/', [System.IO.Path]::DirectorySeparatorChar))))
                if (-not (Test-Path -LiteralPath $resolved)) { [void]$broken.Add("$relativePath -> $target") }
            } catch { [void]$broken.Add("$relativePath -> $target（路径格式无效）") }
        }
    }
    Add-Check 'Markdown 相对链接' ($broken.Count -eq 0) ($broken -join '；')
}

function Get-WorkflowFiles([string]$RelativeDirectory) {
    $root = Join-Path $script:BaselineRoot $RelativeDirectory
    try {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            Add-Check "模块目录：$RelativeDirectory" $false "目录不存在：$RelativeDirectory"
            return @()
        }
        return @(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
            ($RelativeDirectory.TrimEnd('/', '\') + '/' + $_.FullName.Substring($root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/'))
        })
    } catch {
        Add-Check "模块目录：$RelativeDirectory" $false "读取失败：$($_.Exception.Message)"
        return @()
    }
}

function Get-AstStringValue($Ast) {
    $node = $Ast
    if ($node -is [System.Management.Automation.Language.PipelineAst]) { $node = $node.PipelineElements | Select-Object -First 1 }
    if ($node -is [System.Management.Automation.Language.CommandExpressionAst]) { $node = $node.Expression }
    if ($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $node.Value }
    return $null
}

function Get-OptionalMappingPairs([string]$RelativePath) {
    $path = Join-Path $script:BaselineRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Check "AST 映射：$RelativePath" $false '脚本文件不存在'
        return @()
    }
    try {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) {
            Add-Check "AST 映射：$RelativePath" $false '脚本语法解析失败'
            return @()
        }
        $assignments = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.Left.VariablePath.UserPath -eq 'optionalMappings' }, $true))
        Add-Check "AST 映射赋值：$RelativePath" ($assignments.Count -eq 1) '必须且只能存在一个 $optionalMappings 赋值'
        if ($assignments.Count -ne 1) { return @() }
        $pairs = New-Object 'System.Collections.Generic.List[string]'
        foreach ($table in @($assignments[0].Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true))) {
            $values = @{}
            foreach ($entry in $table.KeyValuePairs) {
                $key = Get-AstStringValue $entry.Item1
                if ($key -in @('Source', 'Target')) { $values[$key] = Get-AstStringValue $entry.Item2 }
            }
            if ($values.ContainsKey('Source') -and $values.ContainsKey('Target')) {
                [void]$pairs.Add($values['Source'].Replace('\', '/') + '->' + $values['Target'].Replace('\', '/'))
            }
        }
        return @($pairs)
    } catch {
        Add-Check "AST 映射：$RelativePath" $false "解析失败：$($_.Exception.Message)"
        return @()
    }
}

function Assert-ReasonCodes([string]$Name, [string]$Text) {
    foreach ($code in @('REMOTE_DRIFT', 'PUSH_OUTCOME_UNKNOWN', 'ARTIFACT_INVALIDATED', 'RELEASE_PARTIAL', 'RELEASE_OUTCOME_UNKNOWN')) {
        Assert-Match "$Name 原因码 $code" $Text ("(?m)\b" + $code + "\b") "缺少原因码 $code"
    }
}

$expectedModuleFiles = @(
    'workflows/three-authority-vibecoding/README.md'
    'workflows/three-authority-vibecoding/activation-rules.md'
    'workflows/three-authority-vibecoding/examples.md'
    'workflows/three-authority-vibecoding/handoff-contract.md'
    'workflows/three-authority-vibecoding/state-machine.md'
    'prompts/three-authority-vibecoding/README.md'
    'prompts/three-authority-vibecoding/approver-window.md'
    'prompts/three-authority-vibecoding/executor-window.md'
    'prompts/three-authority-vibecoding/tester-window.md'
    'templates/three-authority-vibecoding/README.md'
    'templates/three-authority-vibecoding/approval-record.md'
    'templates/three-authority-vibecoding/execution-package.md'
    'templates/three-authority-vibecoding/execution-report.md'
    'templates/three-authority-vibecoding/independent-test-report.md'
    'templates/three-authority-vibecoding/test-request.md'
)
$actualModuleFiles = @(
    (Get-WorkflowFiles 'workflows/three-authority-vibecoding') +
    (Get-WorkflowFiles 'prompts/three-authority-vibecoding') +
    (Get-WorkflowFiles 'templates/three-authority-vibecoding')
)
Assert-SetEqual '三权模块文件集合' $actualModuleFiles $expectedModuleFiles
Test-RelativeMarkdownLinks ($expectedModuleFiles + @('README.md', 'USAGE.md'))

$stateMachine = Read-Utf8 'workflows/three-authority-vibecoding/state-machine.md'
$stateSection = Get-MarkdownSection $stateMachine '状态定义'
$stateRows = @(
    foreach ($line in ($stateSection -split "`r?`n")) {
        $match = [regex]::Match($line, '^\|\s*(?<State>[A-Z][A-Z0-9_]*)\s*\|\s*(?<Role>[^|]+?)\s*\|\s*(?<Pre>[^|]+?)\s*\|\s*(?<Required>[^|]+?)\s*\|\s*(?<Next>[^|]+?)\s*\|$')
        if ($match.Success) {
            [pscustomobject]@{ State = $match.Groups['State'].Value; Role = $match.Groups['Role'].Value.Trim(); Required = $match.Groups['Required'].Value.Trim(); Next = $match.Groups['Next'].Value.Trim() }
        }
    }
)
$expectedStates = @('PLAN_DRAFT', 'PLAN_APPROVED', 'IMPLEMENTING', 'CANDIDATE_READY', 'APPROVE_TEST', 'TEST_REQUEST', 'PASS', 'CONDITIONAL_PASS', 'FAIL', 'TEST_BLOCKED', 'SPEC_GAP', 'R1', 'R2', 'REPLAN', 'REJECT_SCOPE', 'APPROVE_PUSH', 'APPROVE_RELEASE', 'OWNER_APPROVAL_REQUIRED', 'PUSHED', 'RELEASED')
Assert-SetEqual '状态集合' @($stateRows | ForEach-Object State) $expectedStates
Add-Check '状态名唯一' (($stateRows | Group-Object State | Where-Object Count -gt 1).Count -eq 0) '状态表存在重复状态名'
Add-Check 'APPROVE_PUSH 下一状态' (($stateRows | Where-Object State -eq 'APPROVE_PUSH').Next -eq 'PUSHED、REPLAN') '必须精确为 PUSHED、REPLAN'
Add-Check 'APPROVE_RELEASE 下一状态' (($stateRows | Where-Object State -eq 'APPROVE_RELEASE').Next -eq 'RELEASED、TEST_REQUEST、REPLAN') '必须精确为 RELEASED、TEST_REQUEST、REPLAN'
Add-Check 'TEST_REQUEST 角色' (($stateRows | Where-Object State -eq 'TEST_REQUEST').Role -eq '审批') '必须由审批窗口输出'
Add-Check 'REPLAN 角色' (($stateRows | Where-Object State -eq 'REPLAN').Role -eq '审批') '必须由审批窗口输出'
Add-Check 'PUSHED 角色' (($stateRows | Where-Object State -eq 'PUSHED').Role -eq '执行') '必须由执行窗口输出'
Add-Check 'RELEASED 角色' (($stateRows | Where-Object State -eq 'RELEASED').Role -eq '执行或获授权发布者') '必须由执行窗口或获授权发布者输出'
$transitionTokens = @(
    foreach ($row in $stateRows) {
        foreach ($match in [regex]::Matches($row.Next, '\b[A-Z][A-Z0-9_]*\b')) { $match.Value }
    }
)
$undefinedTransitions = @($transitionTokens | Where-Object { $_ -notin $expectedStates } | Sort-Object -Unique)
Add-Check '状态表转换闭包' ($undefinedTransitions.Count -eq 0) ('允许下一状态包含未定义状态：' + ($undefinedTransitions -join '、'))
$mainPath = Get-MarkdownSection $stateMachine '主路径'
$mainPathTokens = @([regex]::Matches($mainPath, '\b[A-Z][A-Z0-9_]*\b') | ForEach-Object Value)
$undefinedMainPathStates = @($mainPathTokens | Where-Object { $_ -notin $expectedStates -and $_ -ne 'L3' } | Sort-Object -Unique)
Add-Check '主路径状态闭包' ($undefinedMainPathStates.Count -eq 0) ('主路径包含未定义状态：' + ($undefinedMainPathStates -join '、'))
$releasedRequired = ($stateRows | Where-Object State -eq 'RELEASED').Required
Assert-Match 'RELEASED 状态批准摘要门槛' $releasedRequired '(?s)(?:每个|全部)目标[^。\r\n]{0,120}(?:实际\s*)?Artifact-Digest[^。\r\n]{0,120}(?:均|都)[^。\r\n]{0,40}(?:等于批准摘要|与批准摘要一致)' 'RELEASED 状态必须要求每个目标实际 Artifact-Digest 均等于批准摘要'
Assert-Match 'RELEASED 状态健康检查门槛' $releasedRequired '健康检查[^。\r\n]{0,40}(?:均|全部)[^。\r\n]{0,20}通过' 'RELEASED 状态必须要求健康检查全部通过'

Assert-Match '候选后状态格式' $stateMachine '(?s)Candidate-Commit 已存在.*?<STATE>\s+<full-candidate-hash>' '缺少候选后的完整哈希状态格式'
Assert-Match '候选前状态格式' $stateMachine '(?s)Candidate-Commit 尚不存在.*?<STATE>\s+<Task-ID>\s+<Plan-Revision>\s+<Base-Commit>' '缺少候选前任务三元组状态格式'
Assert-Match 'REPLAN 候选绑定' $stateMachine 'REPLAN\s+<full-candidate-hash>' 'REPLAN 必须绑定完整候选哈希'
Assert-Match 'REJECT_SCOPE 候选绑定' $stateMachine 'REJECT_SCOPE\s+<full-candidate-hash>' 'REJECT_SCOPE 必须绑定完整候选哈希'

$approver = Read-Utf8 'prompts/three-authority-vibecoding/approver-window.md'
$reviewCandidate = Get-MarkdownSection $approver '审查候选提交'
$finalDecision = Get-MarkdownSection $approver '最终裁决'
foreach ($section in @(@{ Name = '审查候选提交'; Text = $reviewCandidate }, @{ Name = '最终裁决'; Text = $finalDecision })) {
    Assert-Match "$($section.Name) REPLAN 绑定" $section.Text 'REPLAN\s+<full-candidate-hash>' 'REPLAN 必须绑定完整候选哈希'
    Assert-Match "$($section.Name) REJECT_SCOPE 绑定" $section.Text 'REJECT_SCOPE\s+<full-candidate-hash>' 'REJECT_SCOPE 必须绑定完整候选哈希'
    Assert-NotMatch "$($section.Name) 禁止任务三元组" $section.Text '(?:REPLAN|REJECT_SCOPE)\s+<Task-ID>\s+<Plan-Revision>\s+<Base-Commit>' '候选后裁决不得绑定任务三元组'
}

$handoff = Read-Utf8 'workflows/three-authority-vibecoding/handoff-contract.md'
$executor = Read-Utf8 'prompts/three-authority-vibecoding/executor-window.md'
$tester = Read-Utf8 'prompts/three-authority-vibecoding/tester-window.md'
$handoffPushRelease = Get-MarkdownSection $handoff '推送、发布与 Owner 证据'
$handoffReasonCodes = Get-MarkdownSection $handoff '原因码'
$executorBoundary = Get-MarkdownSection $executor '角色边界'
$executorActions = Get-MarkdownSection $executor '返工与批准动作'
$testerPreflight = Get-MarkdownSection $tester '测试前强制预检'
$testerReturn = Get-MarkdownSection $tester '回传'
Assert-Match 'handoff 原因码候选前示例' $handoffReasonCodes '<STATE>\s+<Task-ID>\s+<Plan-Revision>\s+<Base-Commit>' '原因码章节缺少候选前状态示例'
Assert-Match 'handoff 原因码候选后示例' $handoffReasonCodes '<STATE>\s+<full-candidate-hash>' '原因码章节缺少候选后状态示例'
$executorAuthorityText = $executorBoundary + "`n" + $executorActions
foreach ($state in @('TEST_REQUEST', 'REPLAN', 'REJECT_SCOPE')) {
    Assert-Match "执行窗口禁止越权 $state" $executorAuthorityText ("(?s)(?:不得自行(?:输出|裁决)[\\s\\S]{0,240}?" + $state + '|' + $state + '[\\s\\S]{0,240}?不得自行(?:输出|裁决))') "相关职责章节必须明确禁止执行窗口自行输出或裁决 $state"
}
Assert-Match 'PUSHED 交接远端哈希对账' $handoffPushRelease '(?s)(?:远端)?实际哈希\s*(?:等于\s*Candidate-Commit|与\s*Candidate-Commit\s*一致)[\s，、；：:]*才可输出\s*PUSHED' '推送、发布与 Owner 证据章节必须明确实际哈希等于或与 Candidate-Commit 一致才可输出 PUSHED'
$approvedDigestPattern = '(?s)(?:每个|全部)目标[^。\r\n]{0,120}(?:实际\s*)?Artifact-Digest[^。\r\n]{0,120}(?:均|都)[^。\r\n]{0,40}(?:等于批准摘要|与批准摘要一致)'
Assert-Match 'RELEASED 交接批准摘要匹配' $handoffPushRelease $approvedDigestPattern '交接章节必须明确每个目标实际 Artifact-Digest 均等于批准摘要'
Assert-Match 'RELEASED 交接健康检查匹配' $handoffPushRelease '(?s)健康检查\s*(?:均匹配|均通过)[^。\r\n]*才可输出\s*RELEASED' '交接章节必须明确健康检查均匹配或通过才可输出 RELEASED'
Assert-Match 'RELEASED 执行窗口批准摘要匹配' $executorActions $approvedDigestPattern '执行窗口必须明确每个目标实际 Artifact-Digest 均等于批准摘要'
Assert-Match 'RELEASED 执行窗口健康检查匹配' $executorActions '(?s)健康检查\s*(?:均匹配|均通过)[^。\r\n]*才可输出\s*RELEASED' '执行窗口必须明确健康检查均匹配或通过才可输出 RELEASED'
Assert-Match '交接契约禁止重放旧 Owner 证据' $handoffPushRelease '(?s)旧\s*`?APPROVE_RELEASE`?[^。\r\n]{0,80}`?Owner-Evidence`?[^。\r\n]{0,120}不得重放' '交接契约必须同时禁止重放旧 APPROVE_RELEASE 和 Owner-Evidence'
Assert-Match '测试窗口预检 TEST_BLOCKED 候选绑定' $testerPreflight '(?m)^\s*TEST_BLOCKED\s+<full-candidate-hash>\s+reason=HASH_NOT_VERIFIED\s*$' '哈希无法验证时仍必须回显请求的完整 Candidate-Commit'
Assert-Match '测试窗口环境阻塞 TEST_BLOCKED 候选绑定' $testerPreflight 'TEST_BLOCKED\s+<full-candidate-hash>\s+reason=BLOCKED_ENVIRONMENT' '环境或依赖阻塞时仍必须回显请求的完整 Candidate-Commit'
Assert-Match '测试窗口预检 Actual-HEAD 可未知' $testerPreflight '(?m)^\s*Actual-HEAD:\s*<actual-full-hash-or-UNKNOWN>\s*$' '无法解析的是 Actual-HEAD，必须与请求的 Candidate-Commit 分开记录'
Assert-Match '测试窗口回传 TEST_BLOCKED 候选绑定' $testerReturn '(?m)^\s*TEST_BLOCKED\s+<full-candidate-hash>\s+reason=<code>\s*$' 'TEST_BLOCKED 回传必须绑定请求的完整候选哈希'
Assert-NotMatch '测试窗口 TEST_BLOCKED 禁止 NONE' $tester '(?m)^\s*TEST_BLOCKED[^\r\n]*(?:-or-NONE|\bNONE\b)' 'TEST_BLOCKED 不得把请求的候选哈希降级为 NONE'

$workflowReadme = Read-Utf8 'workflows/three-authority-vibecoding/README.md'
$usage = Read-Utf8 'USAGE.md'
$examples = Read-Utf8 'workflows/three-authority-vibecoding/examples.md'
$workflowStandardFlow = Get-MarkdownSection $workflowReadme '标准流程'
$usagePushRelease = Get-MarkdownSection $usage '10. 三权分离完整实操'
$examplePushFailure = Get-MarkdownSection $examples '6. 推送失败只回传证据，由审批窗口裁决'
$exampleReleaseFailure = Get-MarkdownSection $examples '7. 发布失败按是否产生部署副作用分流'
$exampleFailures = $examplePushFailure + $exampleReleaseFailure
$contractDocuments = @(@{ Name = '审批 Prompt 最终裁决'; Text = $finalDecision }, @{ Name = '交接契约推送发布条款'; Text = $handoffPushRelease }, @{ Name = '工作流 README 标准流程'; Text = $workflowStandardFlow }, @{ Name = 'USAGE 推送发布'; Text = $usagePushRelease }, @{ Name = '示例新失败场景'; Text = $exampleFailures })
foreach ($document in $contractDocuments) {
    Assert-Match "$($document.Name) 批准推送失败出口" $document.Text '(?s)(?=.*(?:APPROVE_PUSH|批准推送))(?=.*(?:REPLAN|REMOTE_DRIFT|PUSH_OUTCOME_UNKNOWN))' '缺少批准推送失败出口'
    Assert-Match "$($document.Name) 批准发布失败出口" $document.Text '(?s)(?=.*(?:APPROVE_RELEASE|批准发布))(?=.*(?:TEST_REQUEST|REPLAN|ARTIFACT_INVALIDATED|RELEASE_PARTIAL|RELEASE_OUTCOME_UNKNOWN))' '缺少批准发布失败出口'
}
Assert-ReasonCodes '契约文档合并文本' (($contractDocuments | ForEach-Object Text) -join "`n")
$releasePremisePattern = '(?s)(?:部署策略|发布策略)[^。\r\n]{0,80}目标环境[^。\r\n]{0,120}(?:发布前提|其他前提)[^。\r\n]{0,120}(?:变化|失效)[^。\r\n]{0,400}REPLAN\s+<full-candidate-hash>'
foreach ($document in @(@{ Name = '状态机'; Text = $stateMachine }, @{ Name = '交接契约'; Text = $handoffPushRelease }, @{ Name = '审批 Prompt'; Text = $finalDecision }, @{ Name = '执行 Prompt'; Text = $executorActions }, @{ Name = '工作流 README'; Text = $workflowStandardFlow }, @{ Name = 'USAGE'; Text = $usagePushRelease })) {
    Assert-Match "$($document.Name) 发布前非制品前提失效" $document.Text $releasePremisePattern '部署策略、目标环境或其他发布前提在发布前变化或失效时，必须由审批窗口输出 REPLAN <full-candidate-hash>'
}
$pushReconciliationPattern = '(?s)(?:非零|异常)[^。\r\n]{0,240}(?:重读|重新读取)[^。\r\n]{0,160}Push-Ref[^。\r\n]{0,240}(?:实际哈希[^。\r\n]{0,80}(?:等于|一致)[^。\r\n]{0,80}Candidate-Commit|Candidate-Commit[^。\r\n]{0,80}(?:等于|一致)[^。\r\n]{0,80}实际哈希)[^。\r\n]{0,160}PUSHED'
foreach ($document in @(@{ Name = '审批 Prompt'; Text = $finalDecision }, @{ Name = '执行 Prompt'; Text = $executorActions }, @{ Name = 'USAGE'; Text = $usagePushRelease }, @{ Name = '推送失败示例'; Text = $examplePushFailure })) {
    Assert-Match "$($document.Name) 命令异常后远端成功对账" $document.Text $pushReconciliationPattern '必须明确命令非零或异常后重读精确 Push-Ref，实际哈希等于 Candidate-Commit 时输出 PUSHED'
}

$approvalRecord = Read-Utf8 'templates/three-authority-vibecoding/approval-record.md'
$approvalState = Get-MarkdownSection $approvalRecord 'State'
Assert-Match '审批记录推送 FAILED' $approvalRecord 'PUSH.*FAILED' '审批记录必须表达推送 FAILED'
Assert-Match '审批记录推送 UNKNOWN' $approvalRecord 'PUSH.*UNKNOWN' '审批记录必须表达推送 UNKNOWN'
Assert-Match '审批记录发布 FAILED' $approvalRecord 'RELEASE.*FAILED' '审批记录必须表达发布 FAILED'
Assert-Match '审批记录发布 PARTIAL' $approvalRecord 'RELEASE.*PARTIAL' '审批记录必须表达发布 PARTIAL'
Assert-Match '审批记录发布 UNKNOWN' $approvalRecord 'RELEASE.*UNKNOWN' '审批记录必须表达发布 UNKNOWN'
Assert-Match '审批记录 State 候选绑定' $approvalState '(?m)^\{\{STATE\}\}\s+\{\{FULL_CANDIDATE_COMMIT\}\}\s*$' 'State 章节必须精确绑定 {{STATE}} {{FULL_CANDIDATE_COMMIT}}'

$rootReadme = Read-Utf8 'README.md'
$readmeDirectory = Get-MarkdownSection $rootReadme '目录职责'
$readmeQuickUse = Get-MarkdownSection $rootReadme '快速使用'
$versionText = Read-Utf8 'VERSION'
$version = if ($null -eq $versionText) { '' } else { $versionText.Trim() }
$schema = $null
$schemaText = Read-Utf8 'schemas/project-rule-profile.example.json'
if ($null -ne $schemaText) {
    try { $schema = $schemaText | ConvertFrom-Json } catch { Add-Check 'schema 解析' $false "解析失败：$($_.Exception.Message)" }
}
$changelog = Read-Utf8 'CHANGELOG.md'
Assert-Match 'README 自检脚本清单' $readmeDirectory '(?m)^.*scripts/.*Test-ThreeAuthorityWorkflow.*$' '目录职责章节的 scripts/ 行缺少自检脚本'
Assert-Match 'README 自检命令' $readmeQuickUse '(?mi)^\s*powershell(?:\.exe)?\s+.*?-File\s+\.\\scripts\\Test-ThreeAuthorityWorkflow\.ps1(?:\s|$)' '快速使用章节缺少完整 powershell -File 自检命令'
Add-Check 'VERSION 严格 SemVer 2.0' ($version -match '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:(?:0|[1-9]\d*)|(?:\d*[A-Za-z-][0-9A-Za-z-]*))(?:\.(?:(?:0|[1-9]\d*)|(?:\d*[A-Za-z-][0-9A-Za-z-]*)))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') "VERSION 不是严格 SemVer 2.0：$version"
Add-Check '版本与 schema 同步' ($null -ne $schema -and $schema.baselineVersion -eq $version) "schema baselineVersion=$($schema.baselineVersion)，VERSION=$version"
Assert-Match 'CHANGELOG 当前版本或未发布章节' $changelog ('(?m)^##\s+(?:\[?' + [regex]::Escape($version) + '\]?|未发布)') 'CHANGELOG 缺少当前版本或未发布章节'

$rolePromptPattern = '(?i)three-authority-vibecoding[\\/](?:approver-window|executor-window|tester-window)\.md'
foreach ($directory in @('core', 'entry-templates', 'project-templates')) {
    try {
        $text = @((Get-ChildItem -LiteralPath (Join-Path $script:BaselineRoot $directory) -Recurse -File -ErrorAction Stop | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, $script:Utf8) }) -join "`n")
    } catch {
        Add-Check "$directory 默认规则层读取" $false "读取失败：$($_.Exception.Message)"
        $text = ''
    }
    Assert-NotMatch "$directory 不引用角色 Prompt" $text $rolePromptPattern '默认规则层不得引用三权角色 Prompt'
}
$scriptDocuments = @(@{ Name = 'Install'; Path = 'scripts/Install-AICodingRule.ps1' }, @{ Name = 'Audit'; Path = 'scripts/Audit-AICodingRule.ps1' })
foreach ($scriptDocument in $scriptDocuments) {
    $mappings = Get-OptionalMappingPairs $scriptDocument.Path
    $expectedMappings = @('workflows/three-authority-vibecoding->docs/ai/workflows/three-authority-vibecoding', 'prompts/three-authority-vibecoding->docs/ai/prompts/three-authority-vibecoding', 'templates/three-authority-vibecoding->docs/ai/templates/three-authority-vibecoding')
    Add-Check "$($scriptDocument.Name) 可选映射无重复" ($mappings.Count -eq @($mappings | Sort-Object -Unique).Count) '可选映射存在重复项'
    Assert-SetEqual "$($scriptDocument.Name) 可选映射集合" $mappings $expectedMappings
}

if ($RunInstallSmoke) {
    $tempRoot = [System.IO.Path]::GetTempPath()
    $sandbox = Join-Path $tempRoot ('AICoding-ThreeAuthority-' + [guid]::NewGuid().ToString('N'))
    try {
        try {
            New-Item -ItemType Directory -Path $sandbox -Force -ErrorAction Stop | Out-Null
            Add-Check '创建临时沙箱' $true ''
        } catch {
            Add-Check '创建临时沙箱' $false "创建失败：$($_.Exception.Message)"
            throw
        }
        $installScript = Join-Path $script:BaselineRoot 'scripts/Install-AICodingRule.ps1'
        $auditScript = Join-Path $script:BaselineRoot 'scripts/Audit-AICodingRule.ps1'
        $beforeWhatIf = Get-TreeHash $sandbox
        $whatIfSucceeded = $false
        try {
            & $installScript -ProjectPath $sandbox -WhatIf | Out-Null
            $whatIfSucceeded = $true
        } catch { Add-Check '安装 WhatIf 调用' $false "外部脚本异常：$($_.Exception.Message)" }
        if ($whatIfSucceeded) {
            $afterWhatIf = Get-TreeHash $sandbox
            Add-Check '安装 WhatIf 目标根无任何子项' (@(Get-ChildItem -LiteralPath $sandbox -Recurse -Force -ErrorAction Stop).Count -eq 0) 'WhatIf 后临时沙箱存在文件或目录'
            Add-Check '安装 WhatIf 整树快照不变' ($null -ne $beforeWhatIf -and $afterWhatIf -eq $beforeWhatIf) 'WhatIf 后临时沙箱整树快照发生变化或计算失败'
        }

        $defaultInstallSucceeded = $false
        try {
            & $installScript -ProjectPath $sandbox | Out-Null
            $defaultInstallSucceeded = $true
        } catch { Add-Check '默认安装调用' $false "外部脚本异常：$($_.Exception.Message)" }
        if ($defaultInstallSucceeded) {
            $defaultRoots = @('workflows', 'prompts', 'templates') | ForEach-Object { Join-Path $sandbox ('docs/ai/' + $_ + '/three-authority-vibecoding') }
            Add-Check '默认安装无三权模块' (@($defaultRoots | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0) '默认安装意外写入三权模块'
        }

        $optionalInstallSucceeded = $false
        try {
            & $installScript -ProjectPath $sandbox -IncludeThreeAuthorityWorkflow | Out-Null
            $optionalInstallSucceeded = $true
        } catch { Add-Check '可选安装调用' $false "外部脚本异常：$($_.Exception.Message)" }
        $installed = @()
        $docsAiRoot = Join-Path $sandbox 'docs/ai'
        if ($optionalInstallSucceeded -and (Test-Path -LiteralPath $docsAiRoot -PathType Container)) {
            try {
                $installed = @(Get-ChildItem -LiteralPath $docsAiRoot -Recurse -File -ErrorAction Stop |
                    Where-Object { $_.FullName -match '[\\/]three-authority-vibecoding[\\/]' } |
                    ForEach-Object { $_.FullName.Substring($docsAiRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/') })
            } catch { Add-Check '可选安装文件枚举' $false "读取失败：$($_.Exception.Message)" }
        } elseif ($optionalInstallSucceeded) {
            Add-Check '可选安装文件枚举' $false '安装后缺少 docs/ai 目录'
        }
        $expectedInstalled = $expectedModuleFiles
        Assert-SetEqual '可选安装文件集合' $installed $expectedInstalled
        foreach ($relative in $expectedModuleFiles) {
            $source = Join-Path $script:BaselineRoot $relative
            $target = Join-Path $sandbox ('docs/ai/' + $relative)
            try {
                if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                    Add-Check "可选安装 SHA-256 $relative" $false '安装目标不存在'
                } else {
                    Add-Check "可选安装 SHA-256 $relative" ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -eq (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash) '安装文件与基线不一致'
                }
            } catch { Add-Check "可选安装 SHA-256 $relative" $false "哈希失败：$($_.Exception.Message)" }
        }
        $beforeRepeat = Get-TreeHash $sandbox
        $repeatSucceeded = $false
        try {
            & $installScript -ProjectPath $sandbox -IncludeThreeAuthorityWorkflow | Out-Null
            $repeatSucceeded = $true
        } catch { Add-Check '重复可选安装调用' $false "外部脚本异常：$($_.Exception.Message)" }
        if ($repeatSucceeded) {
            $afterRepeat = Get-TreeHash $sandbox
            Add-Check '重复安装整树哈希不变' ($null -ne $beforeRepeat -and $afterRepeat -eq $beforeRepeat) '重复安装改变了临时项目或目录哈希失败'
        }
        $beforeAudit = Get-TreeHash $sandbox
        try {
            $auditOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -ProjectPath $sandbox 2>&1 | Out-String)
            $auditExitCode = $LASTEXITCODE
            $auditText = $auditOutput -join "`n"
            Add-Check 'Audit 退出码为零' ($auditExitCode -eq 0) "Audit 退出码为 $auditExitCode"
            Add-Check 'Audit 可选三权已安装' ([regex]::IsMatch($auditText, '可选三权工作流：已安装')) 'Audit 未输出可选三权工作流已安装的稳定正向结果'
            Add-Check 'Audit WARN 为零' (-not [regex]::IsMatch($auditText, '\[WARN\]|WARN\s')) '临时项目审计出现 WARN'
        } catch {
            Add-Check 'Audit 调用' $false "外部脚本异常：$($_.Exception.Message)"
            Add-Check 'Audit 退出码为零' $false 'Audit 未完成，无法确认退出码'
            Add-Check 'Audit 可选三权已安装' $false 'Audit 未完成，未输出稳定正向结果'
            Add-Check 'Audit WARN 为零' $false 'Audit 未完成，无法确认 WARN'
        } finally {
            $afterAudit = Get-TreeHash $sandbox
            Add-Check 'Audit 整树快照不变' ($null -ne $beforeAudit -and $afterAudit -eq $beforeAudit) 'Audit 修改或删除了临时项目内容'
        }
    } catch {
        Add-Check '安装冒烟流程' $false "未完成：$($_.Exception.Message)"
    } finally {
        $fullSandbox = [System.IO.Path]::GetFullPath($sandbox)
        $fullTempRoot = [System.IO.Path]::GetFullPath($tempRoot).TrimEnd([char[]]@('\', '/'))
        $insideTemp = $fullSandbox.StartsWith($fullTempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        Add-Check '临时沙箱清理边界' $insideTemp "拒绝清理系统临时目录外的路径：$fullSandbox"
        if ($insideTemp -and (Test-Path -LiteralPath $fullSandbox)) {
            try {
                Remove-Item -LiteralPath $fullSandbox -Recurse -Force -ErrorAction Stop
                Add-Check '临时沙箱已清理' (-not (Test-Path -LiteralPath $fullSandbox)) '临时沙箱未被清理'
            } catch { Add-Check '临时沙箱已清理' $false "清理失败：$($_.Exception.Message)" }
        }
    }
}

Complete-Check
