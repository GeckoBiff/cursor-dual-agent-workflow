# _common.ps1 — shared helpers for dual-agent workflow hooks
# 所有 hook 脚本都 dot-source 这个文件： . "$PSScriptRoot\_common.ps1"

function Read-UTF8File {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-UTF8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Read-StdinJson {
    # 读 stdin，解析 JSON。失败返回 $null
    $raw = ''
    try { $raw = [Console]::In.ReadToEnd() } catch { return $null }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Resolve-WorkspaceRoot {
    param($HookInput)
    # 1. 从 hook stdin JSON 里找工作区根路径
    if ($HookInput) {
        foreach ($k in @('workspace_root','workspaceRoot','cwd','project_root','projectRoot','workspace')) {
            $v = $HookInput.$k
            if ($v) { return [string]$v }
        }
    }
    # 2. 从环境变量
    foreach ($e in @('CURSOR_WORKSPACE_ROOT','WORKSPACE_ROOT')) {
        $v = [Environment]::GetEnvironmentVariable($e)
        if ($v) { return $v }
    }
    # 3. fallback: 当前目录（项目级 hook 时 Cursor 会把 cwd 设到项目根）
    return (Get-Location).Path
}

function Resolve-WorkflowDir {
    # 返回当前项目的工作流文档目录的绝对路径；找不到返回 $null
    # 查找顺序：
    #   1. 环境变量 CURSOR_WORKFLOW_DIR（允许完全自定义）
    #   2. ~/cursor-workflow/<项目根的 leaf 目录名>/
    #   3. <workspace>/docs/workflow/（向后兼容）
    param([string]$WorkspaceRoot)

    if ($env:CURSOR_WORKFLOW_DIR) {
        $p = $env:CURSOR_WORKFLOW_DIR
        if (Test-Path $p) { return (Resolve-Path $p).Path }
    }

    if ($WorkspaceRoot) {
        $projectName = Split-Path -Leaf $WorkspaceRoot
        if ($projectName) {
            $candidate = Join-Path $HOME "cursor-workflow\$projectName"
            if (Test-Path $candidate) { return $candidate }
        }

        $fallback = Join-Path $WorkspaceRoot "docs\workflow"
        if (Test-Path $fallback) { return $fallback }
    }

    return $null
}

function Get-WorkflowState {
    # 返回 @{ StateObj, StatePath, WorkflowDir } 或 $null（未找到 state.json）
    param([string]$WorkspaceRoot)
    $wfDir = Resolve-WorkflowDir -WorkspaceRoot $WorkspaceRoot
    if (-not $wfDir) { return $null }
    $statePath = Join-Path $wfDir 'state.json'
    if (-not (Test-Path $statePath)) { return $null }
    try {
        $stateObj = (Read-UTF8File -Path $statePath) | ConvertFrom-Json
    } catch {
        return $null
    }
    return @{
        StateObj    = $stateObj
        StatePath   = $statePath
        WorkflowDir = $wfDir
    }
}
