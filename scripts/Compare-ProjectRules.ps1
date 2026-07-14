# Compare-ProjectRules.ps1
# 只读比较：项目规则文件 vs 通用基线，输出缺失 / 一致 / 漂移 / 项目扩展。
# 默认不做任何同步；同步决策交给人工。
# 用法：.\Compare-ProjectRules.ps1 -ProjectPath E:\work\project\demo
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [switch]$ShowDiff   # 显示漂移的具体差异行（可能较长）
)

$ErrorActionPreference = 'Stop'
function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}
function Normalize([string]$Text) {
    return (($Text -replace "`r`n", "`n").Trim())
}

$BaselineRoot = Split-Path -Parent $PSScriptRoot
$VersionFile  = Join-Path $BaselineRoot 'VERSION'
$BaselineVersion = if (Test-Path $VersionFile) { (Read-Utf8 $VersionFile).Trim() } else { '(未知)' }

if (-not (Test-Path $ProjectPath)) { throw "项目路径不存在：$ProjectPath" }
$ProjectPath = (Resolve-Path $ProjectPath).Path

Write-Host "== AICoding-RULE 基线比较（基线 v$BaselineVersion）==" -ForegroundColor Cyan
Write-Host "项目：$ProjectPath"
Write-Host ""

$Pairs = @(
    @{ Name = 'core/01_READING_RULES';   Core = 'core\01_READING_RULES.md';   Project = 'docs\ai\01_READING_RULES.md' }
    @{ Name = 'core/02_EXECUTION_RULES'; Core = 'core\02_EXECUTION_RULES.md'; Project = 'docs\ai\02_EXECUTION_RULES.md' }
    @{ Name = 'core/03_TESTING_RULES';   Core = 'core\03_TESTING_RULES.md';   Project = 'docs\ai\03_TESTING_RULES.md' }
    @{ Name = 'core/04_OUTPUT_RULES';    Core = 'core\04_OUTPUT_RULES.md';    Project = 'docs\ai\04_OUTPUT_RULES.md' }
    @{ Name = 'core/05_DOCUMENT_GOVERNANCE_RULES'; Core = 'core\05_DOCUMENT_GOVERNANCE_RULES.md'; Project = 'docs\ai\05_DOCUMENT_GOVERNANCE_RULES.md' }
)

$Results = @()
foreach ($pair in $Pairs) {
    $coreText = Normalize (Read-Utf8 (Join-Path $BaselineRoot $pair.Core))
    $projFull = Join-Path $ProjectPath $pair.Project
    $status = ''; $note = ''

    if (-not (Test-Path $projFull)) {
        $status = 'MISSING'; $note = '项目缺少该规则文件（可用 Install 脚本创建）'
    } else {
        $projText = Read-Utf8 $projFull
        $blockMatch = [regex]::Match($projText,
            "(?s)<!--\s*AICODING-RULE:BEGIN\s+name=$([regex]::Escape($pair.Name))\s+version=(?<ver>\S+)[^>]*-->(?<body>.*?)<!--\s*AICODING-RULE:END",
            'IgnoreCase')
        if ($blockMatch.Success) {
            $blockVer  = $blockMatch.Groups['ver'].Value
            $blockBody = Normalize $blockMatch.Groups['body'].Value
            if ($blockBody -eq $coreText) {
                $status = 'MATCH'; $note = "受控区块与基线一致（区块版本 $blockVer）"
            } else {
                $status = 'DRIFT'
                $diff = Compare-Object ($coreText -split "`n") ($blockBody -split "`n")
                $note = "受控区块与基线不一致（区块版本 $blockVer，差异 $(($diff | Measure-Object).Count) 行）— 手改区块或版本落后，需人工裁决"
                if ($ShowDiff) {
                    $diff | Select-Object -First 40 | ForEach-Object {
                        $mark = if ($_.SideIndicator -eq '<=') { '基线' } else { '项目' }
                        Write-Host ("  [{0}] {1}" -f $mark, $_.InputObject) -ForegroundColor DarkGray
                    }
                }
            }
            # 扩展区：区块外的标题
            $outside = $projText.Remove($blockMatch.Index, $blockMatch.Length)
            $extHeads = [regex]::Matches($outside, '(?m)^#{1,2}\s+(.+)$') |
                ForEach-Object { $_.Groups[1].Value.Trim() } |
                Where-Object { $_ -and ($_ -notmatch '^项目扩展规则') } | Select-Object -First 8
            if (($extHeads | Measure-Object).Count -gt 0) {
                $note += "；扩展区标题：" + ($extHeads -join ' / ')
            }
        } else {
            # 无受控区块：项目自有规则，与基线做主题级粗对比
            $status = 'CUSTOM'
            $projNorm = Normalize $projText
            $coreHeads = [regex]::Matches($coreText, '(?m)^#\s+(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
            $missingHeads = @()
            foreach ($h in $coreHeads) {
                $hKey = ($h -replace '^\d+[A-Z]?\.\s*', '')
                if ($hKey -and -not $projNorm.Contains($hKey)) { $missingHeads += $h }
            }
            if ($missingHeads.Count -eq 0) {
                $note = '项目自有规则（无受控区块），基线全部主题均有对应章节；差异属措辞级，人工抽查'
            } else {
                $note = "项目自有规则（无受控区块），疑似缺少基线主题：" + (($missingHeads | Select-Object -First 6) -join '；')
                if ($missingHeads.Count -gt 6) { $note += "（共 $($missingHeads.Count) 项）" }
            }
        }
    }
    $Results += [pscustomobject]@{ Rule = $pair.Name; Status = $status; Note = $note }
}

$Results | Format-Table -AutoSize -Wrap
Write-Host ""
Write-Host "状态说明：MATCH=与基线一致；DRIFT=受控区块被改或落后；CUSTOM=项目自有规则（合法覆盖候选，人工裁决）；MISSING=缺失。" -ForegroundColor DarkGray
Write-Host "本脚本不自动同步任何内容。" -ForegroundColor DarkGray
