# inject-state.ps1 — sessionStart hook (user-level)
# 作用：把当前项目的 docs/workflow/state.json 摘要作为上下文注入到新会话。
# 工作流目录查找顺序见 _common.ps1 中 Resolve-WorkflowDir。
# 失败策略：fail-open，不阻塞会话启动。

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$hookInput = Read-StdinJson
$workspaceRoot = Resolve-WorkspaceRoot -HookInput $hookInput

$wf = Get-WorkflowState -WorkspaceRoot $workspaceRoot
if (-not $wf) {
    # 该项目没启用双 agent 工作流（没 state.json）。静默 no-op。
    [Console]::Error.WriteLine("[inject-state] no workflow state found for workspace: $workspaceRoot")
    exit 0
}

$state = $wf.StateObj
$wfDir = $wf.WorkflowDir

$phaseLabel = if ([int]$state.current_phase -gt 0) { ('{0:D2}' -f [int]$state.current_phase) } else { '-' }
$reworkCount = 0
if ($state.rework_items) { $reworkCount = @($state.rework_items).Count }

$nextHint = switch ($state.status) {
    'arch_design'       { 'arch: 产出 ARCHITECTURE.md + PHASES.md + phase-01-plan.md，然后把 status 改为 ready_for_coding' }
    'phase_planning'    { "arch: 写 phase-$phaseLabel-plan.md，然后 status=ready_for_coding" }
    'ready_for_coding'  { "coder: 读 phase-$phaseLabel-plan.md 开始实现，status 改为 coding" }
    'coding'            { "coder: 继续实现；完成节点时起草 phase-$phaseLabel-summary.md 并 status=awaiting_review" }
    'awaiting_review'   { "arch: 切过来做 code review，产出 phase-$phaseLabel-review.md" }
    'reviewing'         { "arch: 完成 phase-$phaseLabel-review.md 的 verdict" }
    'rework'            { 'coder: 按 state.rework_items 整改，完成后 status=awaiting_review' }
    'phase_done'        { 'arch: 定稿 summary，写下阶段 plan（或 status=all_done）' }
    'all_done'          { '全部阶段完成，无需继续' }
    default             { '状态未知，请先修正 state.json' }
}

$ctx = @"
[Dual-Agent Workflow — injected by sessionStart hook]

Workflow directory : $wfDir
task_title         : $($state.task_title)
current_phase      : $phaseLabel  (total_phases=$($state.total_phases))
status             : $($state.status)
last_actor         : $($state.last_actor)
last_event         : $($state.last_event)
updated_at         : $($state.updated_at)
rework_items       : $reworkCount
notes              : $($state.notes)

Next expected action: $nextHint

Rules of engagement:
1. state.json lives at: $($wf.StatePath). Read it before acting; update it at the end of your action.
2. Identify whether you are 'arch' or 'coder' based on the active @role-* rule. If neither rule is active, ask the user.
3. Respect role boundaries defined in workflow-core rule.
"@

$out = @{ additional_context = $ctx } | ConvertTo-Json -Compress
Write-Output $out

[Console]::Error.WriteLine("[inject-state] injected state: $($state.status) phase=$phaseLabel from $wfDir")
exit 0
