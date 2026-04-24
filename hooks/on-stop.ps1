# on-stop.ps1 — stop hook (user-level)
# 作用：agent 停机时检查 state 与产物是否一致，发现"该产出而未产出"时返回 followup_message。
# 失败策略：fail-open。

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$hookInput = Read-StdinJson
$workspaceRoot = Resolve-WorkspaceRoot -HookInput $hookInput

$wf = Get-WorkflowState -WorkspaceRoot $workspaceRoot
if (-not $wf) { exit 0 }

$state = $wf.StateObj
$wfDir = $wf.WorkflowDir

$phaseNum   = [int]$state.current_phase
$phaseLabel = '{0:D2}' -f $phaseNum
$planFile     = Join-Path $wfDir "phase-$phaseLabel-plan.md"
$summaryFile  = Join-Path $wfDir "phase-$phaseLabel-summary.md"
$reviewFile   = Join-Path $wfDir "phase-$phaseLabel-review.md"
$phasesFile   = Join-Path $wfDir 'PHASES.md'
$archFile     = Join-Path $wfDir 'ARCHITECTURE.md'

function Get-SummaryDraftStatus {
    param([string]$path)
    if (-not (Test-Path $path)) { return 'missing' }
    $text = Read-UTF8File -Path $path
    if (-not $text) { return 'missing' }
    $head = $text.Substring(0, [Math]::Min(1000, $text.Length))
    if ($head -match '(?ms)^---.*?status:\s*finalized.*?---') { return 'finalized' }
    if ($head -match '(?ms)^---.*?status:\s*draft.*?---')     { return 'draft' }
    return 'exists_no_status'
}

function Get-ReviewVerdict {
    param([string]$path)
    if (-not (Test-Path $path)) { return 'missing' }
    $text = Read-UTF8File -Path $path
    $head = $text.Substring(0, [Math]::Min(1000, $text.Length))
    if ($head -match '(?im)^verdict:\s*APPROVED') { return 'APPROVED' }
    if ($head -match '(?im)^verdict:\s*REJECTED') { return 'REJECTED' }
    return 'unknown'
}

$followup = $null

switch ($state.status) {

    'arch_design' {
        $missing = @()
        if (-not (Test-Path $archFile))   { $missing += 'ARCHITECTURE.md' }
        if (-not (Test-Path $phasesFile)) { $missing += 'PHASES.md' }
        if (-not (Test-Path $planFile) -and $phaseNum -ge 1) { $missing += "phase-$phaseLabel-plan.md" }
        if ($missing.Count -gt 0) {
            $followup = "[workflow hook] status=arch_design 但工作流目录缺失 $($missing -join ', ')（$wfDir）。请按 role-arch 规则补齐这些文件，然后把 state.status 更新为 ready_for_coding。"
        }
    }

    'coding' {
        $s = Get-SummaryDraftStatus $summaryFile
        if ($s -eq 'missing') {
            $followup = "[workflow hook] status=coding 且 phase-$phaseLabel-summary.md 尚未创建。若本阶段代码已实现完成，请从 _templates/phase-summary.template.md 复制模板起草 summary（frontmatter status: draft），跑 make 贴自测结果，然后把 state.status 改为 awaiting_review。若代码还没写完，忽略此提示继续实现。"
        }
    }

    'awaiting_review' {
        $s = Get-SummaryDraftStatus $summaryFile
        if ($s -eq 'missing') {
            $followup = "[workflow hook] status=awaiting_review 但 phase-$phaseLabel-summary.md 不存在，非法状态。请先由 coder 起草 summary，或把 state.status 回退到 coding。"
        }
    }

    'reviewing' {
        $v = Get-ReviewVerdict $reviewFile
        if ($v -eq 'missing' -or $v -eq 'unknown') {
            $followup = "[workflow hook] status=reviewing 但 phase-$phaseLabel-review.md 未就绪或 frontmatter 缺 verdict。请按 role-arch 规则完成 review 并填 verdict: APPROVED 或 REJECTED。"
        }
    }

    'phase_done' {
        $s = Get-SummaryDraftStatus $summaryFile
        if ($s -ne 'finalized') {
            $nextPhase = '{0:D2}' -f ($phaseNum + 1)
            $followup = "[workflow hook] status=phase_done 但 phase-$phaseLabel-summary.md 尚未定稿（frontmatter status 应为 finalized）。请由 arch 定稿 summary；若还有下阶段则写 phase-$nextPhase-plan.md 并把 state.status 改为 ready_for_coding；若是最后阶段则改为 all_done。"
        }
    }

    default { }
}

if ($null -ne $followup) {
    $out = @{ followup_message = $followup } | ConvertTo-Json -Compress
    Write-Output $out
    [Console]::Error.WriteLine("[on-stop] followup emitted for status=$($state.status)")
} else {
    [Console]::Error.WriteLine("[on-stop] no followup needed; status=$($state.status)")
}

exit 0
