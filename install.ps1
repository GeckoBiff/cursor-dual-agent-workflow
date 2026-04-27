# install.ps1 — 把本仓库内容部署到 ~/.cursor/ 对应位置
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Force
#
# 特性：
#   - 幂等：重复运行无副作用
#   - 如目标已存在且与本仓库版本不同，默认备份到 ~/.cursor/backup-<timestamp>/ 后覆盖
#   - -Force：跳过备份直接覆盖（不推荐首次使用）
#   - 安装完成后提示是否需要重启 Cursor

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipMergeHooksJson
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$cursorHome = Join-Path $HOME '.cursor'

if (-not (Test-Path $cursorHome)) {
    New-Item -ItemType Directory -Force -Path $cursorHome | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $cursorHome "backup-$timestamp"
$backupCreated = $false

function Ensure-Backup {
    if (-not $backupCreated -and -not $Force) {
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        $script:backupCreated = $true
    }
}

function Backup-ThenRemove {
    param([string]$path)
    if (-not (Test-Path $path)) { return }
    if ($Force) {
        Remove-Item -Recurse -Force $path
        return
    }
    Ensure-Backup
    $rel = $path.Substring($cursorHome.Length).TrimStart('\','/')
    $dst = Join-Path $backupDir $rel
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    Move-Item -Force $path $dst
    Write-Host "  backup -> $dst" -ForegroundColor DarkGray
}

function Install-Item {
    param([string]$srcRelative, [string]$dstRelative)
    $src = Join-Path $repoRoot $srcRelative
    $dst = Join-Path $cursorHome $dstRelative
    if (-not (Test-Path $src)) {
        Write-Warning "源不存在，跳过: $src"
        return
    }
    if (Test-Path $dst) {
        # 如果内容一致就跳过（基于文件哈希的粗略比较）
        $same = $false
        try {
            $srcItem = Get-Item $src
            if ($srcItem.PSIsContainer) {
                $srcFiles = Get-ChildItem $src -Recurse -File | Sort-Object FullName
                $dstFiles = Get-ChildItem $dst -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName
                if ($srcFiles.Count -eq $dstFiles.Count) {
                    $same = $true
                    for ($i = 0; $i -lt $srcFiles.Count; $i++) {
                        $sh = (Get-FileHash $srcFiles[$i].FullName -Algorithm SHA256).Hash
                        $dh = (Get-FileHash $dstFiles[$i].FullName -Algorithm SHA256).Hash
                        if ($sh -ne $dh) { $same = $false; break }
                    }
                }
            } else {
                $sh = (Get-FileHash $src -Algorithm SHA256).Hash
                $dh = (Get-FileHash $dst -Algorithm SHA256).Hash
                $same = ($sh -eq $dh)
            }
        } catch { $same = $false }
        if ($same) {
            Write-Host "  up-to-date     : $dstRelative" -ForegroundColor DarkGray
            return
        }
        Backup-ThenRemove $dst
    }
    Copy-Item -Recurse -Force $src $dst
    Write-Host "  installed      : $dstRelative" -ForegroundColor Green
}

Write-Host "=== Cursor Dual-Agent Workflow Installer ==="
Write-Host "repo          : $repoRoot"
Write-Host "target        : $cursorHome"
Write-Host "backup (if needed) : $backupDir"
Write-Host ""

# 1. hooks/ 目录
Install-Item 'hooks' 'hooks'

# 2. hooks.json —— 如果已存在且非本仓库版本，提示用户手动合并（hooks.json 可能含其他用户的 hook）
$dstHooksJson = Join-Path $cursorHome 'hooks.json'
$srcHooksJson = Join-Path $repoRoot 'hooks.json'
if ((Test-Path $dstHooksJson) -and -not $SkipMergeHooksJson) {
    $srcHash = (Get-FileHash $srcHooksJson).Hash
    $dstHash = (Get-FileHash $dstHooksJson).Hash
    if ($srcHash -ne $dstHash) {
        Write-Host ""
        Write-Warning "检测到 ~/.cursor/hooks.json 已存在且和本仓库不同。"
        Write-Host "  本仓库版本 : $srcHooksJson" -ForegroundColor Yellow
        Write-Host "  你的版本   : $dstHooksJson" -ForegroundColor Yellow
        Write-Host "  为避免覆盖你的其他 hook，默认会备份你的版本，再用本仓库版本替换。"
        Write-Host "  安装完后请手动把你原来的 hooks 条目合并回来。"
        Write-Host ""
    }
}
Install-Item 'hooks.json' 'hooks.json'

# 3. rules-template/
Install-Item 'rules-template' 'rules-template'

# 4. workflow-template/
Install-Item 'workflow-template' 'workflow-template'

# 5. init-workflow.ps1
Install-Item 'init-workflow.ps1' 'init-workflow.ps1'

Write-Host ""
Write-Host "=== 安装完成 ==="
if ($backupCreated) {
    Write-Host "旧文件备份在  : $backupDir" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "下一步："
Write-Host "  1. 如果 Cursor 已在运行，请重启以加载新 hooks"
Write-Host "  2. 在任何项目根目录跑以下命令初始化工作流："
Write-Host "     powershell -NoProfile -ExecutionPolicy Bypass -File `$HOME\.cursor\init-workflow.ps1" -ForegroundColor Cyan
