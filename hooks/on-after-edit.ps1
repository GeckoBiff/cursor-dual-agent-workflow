# on-after-edit.ps1 — afterFileEdit hook (user-level)
# 作用：当 agent 写入 phase-NN-review.md（在任意工作流目录下）时，自动解析 verdict 并流转 state。
#       APPROVED → status=phase_done；REJECTED → status=rework + 填充 rework_items。
# 失败策略：fail-open。

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$payload = Read-StdinJson
if (-not $payload) { exit 0 }

function Find-FilePath {
    param($obj)
    if ($null -eq $obj) { return $null }
    foreach ($k in @('file_path','filePath','path','target_file','targetFile')) {
        $v = $obj.$k
        if ($v) { return [string]$v }
    }
    foreach ($nested in @('tool_input','input','arguments','params','details')) {
        if ($obj.$nested) {
            $r = Find-FilePath $obj.$nested
            if ($r) { return $r }
        }
    }
    return $null
}

$filePath = Find-FilePath $payload
if (-not $filePath) {
    [Console]::Error.WriteLine("[on-after-edit] no file_path in payload; skip")
    exit 0
}

$normalized = $filePath -replace '\\','/'

# 匹配 phase-NN-review.md（在任何路径下都接受，workflow 目录可能是项目外的）
if ($normalized -notmatch 'phase-(\d{2})-review\.md$') {
    exit 0
}
$phaseNum = [int]$Matches[1]
$phaseLabel = '{0:D2}' -f $phaseNum

$workspaceRoot = Resolve-WorkspaceRoot -HookInput $payload

$wf = Get-WorkflowState -WorkspaceRoot $workspaceRoot
if (-not $wf) {
    [Console]::Error.WriteLine("[on-after-edit] cannot resolve workflow dir; skip")
    exit 0
}

$state = $wf.StateObj
$statePath = $wf.StatePath
$wfDir = $wf.WorkflowDir

# 优先用 agent 写的那个路径（可能是相对工作区根的）；若不可直接 read，则在 workflow 目录里找
$reviewAbs = $null
$absCandidates = @()
if ([System.IO.Path]::IsPathRooted($filePath)) {
    $absCandidates += $filePath
}
$absCandidates += (Join-Path $workspaceRoot $filePath)
$absCandidates += (Join-Path $wfDir "phase-$phaseLabel-review.md")
foreach ($c in $absCandidates) {
    if (Test-Path $c) { $reviewAbs = (Resolve-Path $c).Path; break }
}
if (-not $reviewAbs) {
    [Console]::Error.WriteLine("[on-after-edit] review file not locatable: $filePath")
    exit 0
}

$reviewContent = Read-UTF8File -Path $reviewAbs

# 解析 frontmatter 中的 verdict
$verdict = $null
if ($reviewContent -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
    $fm = $Matches[1]
    if ($fm -match '(?im)^\s*verdict:\s*(APPROVED|REJECTED)\s*$') {
        $verdict = $Matches[1].ToUpper()
    }
}

if (-not $verdict) {
    [Console]::Error.WriteLine("[on-after-edit] verdict not found in frontmatter; no state change")
    exit 0
}

# 只在 review 相关状态下响应，防止误触发
$allowed = @('awaiting_review','reviewing','rework','coding')
if ($allowed -notcontains $state.status) {
    [Console]::Error.WriteLine("[on-after-edit] status=$($state.status) not in allowed set; skip")
    exit 0
}

# phase 必须匹配
if ([int]$state.current_phase -ne $phaseNum) {
    [Console]::Error.WriteLine("[on-after-edit] phase mismatch (state=$($state.current_phase), file=$phaseNum); skip")
    exit 0
}

$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

if ($verdict -eq 'APPROVED') {
    $state.status        = 'phase_done'
    $state.last_actor    = 'arch'
    $state.last_event    = "phase_${phaseLabel}_approved"
    $state.updated_at    = $nowIso
    $state.rework_items  = @()
}
elseif ($verdict -eq 'REJECTED') {
    # 从 "整改项" 段落提取未勾选 checklist
    $items = @()
    if ($reviewContent -match '(?ms)##\s*3\..*?整改项.*?\r?\n(.*?)(?:\r?\n##\s|\z)') {
        $block = $Matches[1]
        $lineMatches = [regex]::Matches($block, '(?m)^\s*-\s*\[\s\]\s*(.+?)\s*$')
        foreach ($m in $lineMatches) {
            $txt = $m.Groups[1].Value.Trim()
            if ($txt) { $items += $txt }
        }
    }
    $state.status        = 'rework'
    $state.last_actor    = 'arch'
    $state.last_event    = "phase_${phaseLabel}_rejected"
    $state.updated_at    = $nowIso
    $state.rework_items  = $items
}

$json = $state | ConvertTo-Json -Depth 20
Write-UTF8File -Path $statePath -Content $json

[Console]::Error.WriteLine("[on-after-edit] phase $phaseLabel verdict=$verdict -> state.status=$($state.status), rework_items=$(@($state.rework_items).Count)")

exit 0
