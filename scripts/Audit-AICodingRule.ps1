# Audit-AICodingRule.ps1
# 只读审计：检查项目规则体系的完整性、漂移与文档腐化信号。
# 静态检查仅作辅助，不能判断全部语义冲突；深入审计用 prompts/baseline-rule-audit.md。
# 用法：.\Audit-AICodingRule.ps1 -ProjectPath E:\work\project\demo
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$BaselineRoot = Split-Path -Parent $PSScriptRoot
$VersionFile  = Join-Path $BaselineRoot 'VERSION'
$BaselineVersion = if (Test-Path $VersionFile) { (Read-Utf8 $VersionFile).Trim() } else { '(未知)' }

if (-not (Test-Path $ProjectPath)) { throw "项目路径不存在：$ProjectPath" }
$ProjectPath = (Resolve-Path $ProjectPath).Path

$Findings = New-Object System.Collections.ArrayList
function Add-Finding([string]$Level, [string]$Check, [string]$Detail) {
    [void]$Findings.Add([pscustomobject]@{ Level = $Level; Check = $Check; Detail = $Detail })
}

Write-Host "== AICoding-RULE 审计（基线 v$BaselineVersion）==" -ForegroundColor Cyan
Write-Host "项目：$ProjectPath"
Write-Host ""

# 1. 入口完整性
$Expected = @('CLAUDE.md', 'AGENTS.md',
    'docs\ai\README.md', 'docs\ai\01_READING_RULES.md', 'docs\ai\02_EXECUTION_RULES.md',
    'docs\ai\03_TESTING_RULES.md', 'docs\ai\04_OUTPUT_RULES.md', 'docs\ai\05_PROJECT_CONTEXT.md')
foreach ($rel in $Expected) {
    if (-not (Test-Path (Join-Path $ProjectPath $rel))) {
        Add-Finding 'WARN' '入口完整性' "缺少 $rel"
    }
}

# 2. CLAUDE.md 与 AGENTS.md 漂移
$claudePath = Join-Path $ProjectPath 'CLAUDE.md'
$agentsPath = Join-Path $ProjectPath 'AGENTS.md'
if ((Test-Path $claudePath) -and (Test-Path $agentsPath)) {
    $c = (Read-Utf8 $claudePath) -split "`r?`n"
    $a = (Read-Utf8 $agentsPath) -split "`r?`n"
    $diff = Compare-Object -ReferenceObject $c -DifferenceObject $a
    $diffCount = ($diff | Measure-Object).Count
    if ($diffCount -gt 24) {
        Add-Finding 'WARN' '双入口漂移' "CLAUDE.md 与 AGENTS.md 差异 $diffCount 行（超过入口措辞的合理差异，请人工核对硬约束是否语义一致）"
    } elseif ($diffCount -gt 0) {
        Add-Finding 'INFO' '双入口漂移' "差异 $diffCount 行（少量差异通常是入口措辞，建议抽查）"
    }
}

# 3. 05 膨胀检查
$ctxPath = Join-Path $ProjectPath 'docs\ai\05_PROJECT_CONTEXT.md'
if (Test-Path $ctxPath) {
    $sizeKB = [math]::Round((Get-Item $ctxPath).Length / 1KB, 1)
    if ($sizeKB -gt 80) {
        Add-Finding 'WARN' '05 膨胀' "05_PROJECT_CONTEXT.md 已 ${sizeKB}KB（>80KB，必须触发瘦身审计）"
    } elseif ($sizeKB -gt 60) {
        Add-Finding 'INFO' '05 膨胀' "05_PROJECT_CONTEXT.md 已 ${sizeKB}KB（接近 80KB 上限）"
    }
    $ctx = Read-Utf8 $ctxPath
    $dateAppendMatches = [regex]::Matches($ctx, '(?m)^#+\s*.*\d{4}-\d{2}-\d{2}.*(完成记录|当前状态|同步)')
    if ($dateAppendMatches.Count -ge 5) {
        Add-Finding 'WARN' '05 流水账化' "检测到 $($dateAppendMatches.Count) 个按日期追加的记录型标题，疑似里程碑流水账"
    }
}

# 4. 追加式旧结论信号（活动文档）
$activeDocs = @($claudePath, $agentsPath, $ctxPath,
    (Join-Path $ProjectPath 'docs\ai\README.md'),
    (Join-Path $ProjectPath 'docs\ai\01_READING_RULES.md'),
    (Join-Path $ProjectPath 'docs\ai\02_EXECUTION_RULES.md'),
    (Join-Path $ProjectPath 'docs\ai\03_TESTING_RULES.md'),
    (Join-Path $ProjectPath 'docs\ai\04_OUTPUT_RULES.md')) | Where-Object { $_ -and (Test-Path $_) }
$stalePatterns = @('以最新内容为准', '最新补充：', '当前更新：')
foreach ($doc in $activeDocs) {
    $text = Read-Utf8 $doc
    foreach ($p in $stalePatterns) {
        if ($text.Contains($p)) {
            # 排除治理规则中"禁止……"的引用语境
            $lines = $text -split "`r?`n"
            $hits = $lines | Where-Object { $_.Contains($p) -and ($_ -notmatch '禁止|不得|不允许') }
            if (($hits | Measure-Object).Count -gt 0) {
                Add-Finding 'WARN' '追加式旧结论' "$(Split-Path $doc -Leaf) 含 `"$p`"（非禁止语境），疑似冲突逃避写法"
            }
        }
    }
}

# 5. 归档混入常用入口
$readmePath = Join-Path $ProjectPath 'docs\ai\README.md'
if (Test-Path $readmePath) {
    $lines = (Read-Utf8 $readmePath) -split "`r?`n"
    $inCommon = $false
    foreach ($line in $lines) {
        if ($line -match '^#+\s') { $inCommon = ($line -match '常用入口') }
        elseif ($inCommon -and $line -match 'archive/') {
            Add-Finding 'WARN' '归档纪律' "README `"常用入口`" 区引用了 archive/ 文件：$($line.Trim())（应移到历史追溯/归档入口区）"
        }
    }
}

# 6. 受控区块版本
$blockRegex = 'AICODING-RULE:BEGIN\s+name=(?<name>\S+)\s+version=(?<ver>\S+)'
$managedFiles = @('01_READING_RULES.md','02_EXECUTION_RULES.md','03_TESTING_RULES.md','04_OUTPUT_RULES.md') |
    ForEach-Object { Join-Path $ProjectPath "docs\ai\$_" } | Where-Object { Test-Path $_ }
$anyBlock = $false
foreach ($mf in $managedFiles) {
    $m = [regex]::Match((Read-Utf8 $mf), $blockRegex)
    if ($m.Success) {
        $anyBlock = $true
        $ver = $m.Groups['ver'].Value
        if ($ver -ne $BaselineVersion) {
            Add-Finding 'WARN' '基线版本' "$(Split-Path $mf -Leaf) 受控区块版本 $ver 落后于基线 $BaselineVersion（用 Compare/Install 升级）"
        }
    }
}
if (-not $anyBlock -and ($managedFiles | Measure-Object).Count -gt 0) {
    Add-Finding 'INFO' '基线版本' '规则文件未使用受控区块（可能是项目自有成熟规则；用 Compare-ProjectRules.ps1 对比语义差异）'
}

# 7. README 引用路径有效性（反引号内的相对 md 路径）
if (Test-Path $readmePath) {
    $readme = Read-Utf8 $readmePath
    $refs = [regex]::Matches($readme, '`([^`\r\n]+\.md)`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($ref in $refs) {
        if ($ref -match '^\{\{' -or $ref -match '[\*\?]') { continue }  # 占位符 / 通配跳过
        $refPath = Join-Path (Join-Path $ProjectPath 'docs\ai') $ref
        $refPathRoot = Join-Path $ProjectPath $ref
        if (-not (Test-Path $refPath) -and -not (Test-Path $refPathRoot)) {
            # 兜底：README 表格内常用"同目录简写"，按文件名在 docs/ai 下递归查找
            $leaf = Split-Path $ref -Leaf
            $found = Get-ChildItem -Path (Join-Path $ProjectPath 'docs\ai') -Recurse -Filter $leaf -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $found) {
                Add-Finding 'WARN' '引用失效' "README 引用不存在：$ref"
            }
        }
    }
}

# --- 输出 ---
if ($Findings.Count -eq 0) {
    Write-Host "未发现问题（静态检查范围内）。" -ForegroundColor Green
} else {
    $Findings | Sort-Object Level | Format-Table -AutoSize -Wrap
    $warnCount = ($Findings | Where-Object { $_.Level -eq 'WARN' } | Measure-Object).Count
    Write-Host "共 $($Findings.Count) 项发现（WARN：$warnCount）。" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "注意：本脚本是静态辅助检查，不能自动判断全部语义冲突；语义级审计请用 prompts/baseline-rule-audit.md。" -ForegroundColor DarkGray
