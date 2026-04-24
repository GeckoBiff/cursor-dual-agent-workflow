# init-workflow.ps1 — 新项目一键初始化双 Agent 工作流
#
# 用法（在项目根目录下运行）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.cursor\init-workflow.ps1
#
# 可选参数：
#   -ProjectName <string>    覆盖自动识别的项目名（默认用工作区 leaf 目录名）
#   -UseProjectInternalDocs  把工作流文档放项目内 docs/workflow/ 而非 ~/cursor-workflow/<项目名>/
#   -Force                   覆盖已有文件（否则已存在的文件会跳过）

[CmdletBinding()]
param(
    [string]$ProjectName,
    [switch]$UseProjectInternalDocs,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = (Get-Location).Path
if (-not $ProjectName) { $ProjectName = Split-Path -Leaf $workspaceRoot }

$cursorHome       = Join-Path $HOME '.cursor'
$rulesTemplateDir = Join-Path $cursorHome 'rules-template'
$wfTemplateDir    = Join-Path $cursorHome 'workflow-template'

if (-not (Test-Path $rulesTemplateDir)) { throw "rules-template 不存在：$rulesTemplateDir。请先完成用户级 hooks 安装。" }
if (-not (Test-Path $wfTemplateDir))    { throw "workflow-template 不存在：$wfTemplateDir" }

function Copy-IfMissing {
    param([string]$src, [string]$dst, [switch]$Overwrite)
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Overwrite) {
        Write-Host "  skip (exists)  : $dst"
        return
    }
    Copy-Item -Force $src $dst
    Write-Host "  wrote          : $dst"
}

Write-Host "=== 双 Agent 工作流初始化 ==="
Write-Host "Workspace    : $workspaceRoot"
Write-Host "ProjectName  : $ProjectName"

# 1. 复制规则到项目级 .cursor/rules/
Write-Host ""
Write-Host "[1/3] 安装项目级规则到 .cursor/rules/"
$projectRulesDir = Join-Path $workspaceRoot '.cursor\rules'
foreach ($ruleFile in Get-ChildItem $rulesTemplateDir -Filter '*.mdc') {
    $dst = Join-Path $projectRulesDir $ruleFile.Name
    Copy-IfMissing -src $ruleFile.FullName -dst $dst -Overwrite:$Force
}

# 2. 决定工作流目录位置
Write-Host ""
Write-Host "[2/3] 初始化工作流目录"
if ($UseProjectInternalDocs) {
    $workflowDir = Join-Path $workspaceRoot 'docs\workflow'
    Write-Host "  mode           : project-internal ($workflowDir)"
} else {
    $workflowDir = Join-Path $HOME "cursor-workflow\$ProjectName"
    Write-Host "  mode           : user-global ($workflowDir)"
}
if (-not (Test-Path $workflowDir)) {
    New-Item -ItemType Directory -Force -Path $workflowDir | Out-Null
}

# 3. 从模板复制工作流基础文件
Write-Host ""
Write-Host "[3/3] 铺设工作流基础文件"
foreach ($item in Get-ChildItem $wfTemplateDir -Recurse -File) {
    $rel = $item.FullName.Substring($wfTemplateDir.Length).TrimStart('\','/')
    $dst = Join-Path $workflowDir $rel
    Copy-IfMissing -src $item.FullName -dst $dst -Overwrite:$Force
}

# 给 state.json 设置初始化时间戳（若是新文件）
$statePath = Join-Path $workflowDir 'state.json'
if (Test-Path $statePath) {
    try {
        $raw = [System.IO.File]::ReadAllText($statePath, [System.Text.UTF8Encoding]::new($false))
        $s = $raw | ConvertFrom-Json
        if ($s.updated_at -eq '2026-04-24T00:00:00Z') {
            $s.updated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $s.notes = "workflow initialized for project '$ProjectName'"
            $json = $s | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($statePath, $json, [System.Text.UTF8Encoding]::new($false))
        }
    } catch {}
}

Write-Host ""
Write-Host "=== 完成 ==="
Write-Host "工作流目录 : $workflowDir"
if (-not $UseProjectInternalDocs) {
    Write-Host "提示       : 在代码仓库的 .gitignore 里不需要加任何东西——工作流文档在仓库外。"
} else {
    Write-Host "提示       : 如果不想提交工作流文档，在 .gitignore 加: docs/workflow/"
}
Write-Host ""
Write-Host "下一步 :"
Write-Host "  1. 重启 Cursor 或重新打开本工作区，让 rules 生效"
Write-Host "  2. 在 arch 聊天里: @role-arch <你的需求>"
