# uninstall.ps1 — 从 ~/.cursor/ 移除本框架安装的文件
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -Yes
#
# 注意：
#   - 不会删除 ~/cursor-workflow/ 下的项目数据（那是你的劳动成果）
#   - 不会删除 ~/cursor-dual-agent-workflow/（本仓库本身）
#   - hooks.json 会移除；若你之前还有其他自定义 hook 在里面，请从备份恢复

[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$cursorHome = Join-Path $HOME '.cursor'
$projectDataDir = Join-Path $HOME 'cursor-workflow'

$targets = @(
    (Join-Path $cursorHome 'hooks.json'),
    (Join-Path $cursorHome 'hooks'),
    (Join-Path $cursorHome 'rules-template'),
    (Join-Path $cursorHome 'workflow-template'),
    (Join-Path $cursorHome 'init-workflow.ps1')
)

Write-Host "=== Cursor Dual-Agent Workflow Uninstaller ==="
Write-Host "将要删除的文件/目录："
foreach ($t in $targets) {
    $mark = if (Test-Path $t) { '[存在]' } else { '[不存在]' }
    Write-Host "  $mark $t"
}
Write-Host ""
Write-Host "保留（不会删除）："
Write-Host "  - $projectDataDir  (项目工作流数据)"
Write-Host "  - 各项目的 .cursor/rules/  (项目级规则副本)"
Write-Host ""

if (-not $Yes) {
    $ans = Read-Host "确认卸载？输入 YES 继续，其他内容取消"
    if ($ans -ne 'YES') {
        Write-Host "已取消。"
        exit 0
    }
}

foreach ($t in $targets) {
    if (Test-Path $t) {
        Remove-Item -Recurse -Force $t
        Write-Host "  removed: $t" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== 卸载完成 ==="
Write-Host "提示：重启 Cursor 以使 hooks 变更生效。"
Write-Host "若要同时清理某个项目的 rules 副本，手动删除 <该项目>\.cursor\rules\role-*.mdc 即可。"
