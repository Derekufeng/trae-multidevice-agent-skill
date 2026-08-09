# ============================================================
#  TRAE 配置拉取脚本 (Windows)
#  功能：从 GitHub 仓库拉取最新配置，覆盖本地 ~/.trae-cn/
# ============================================================
#
#  ⏰ 运行时机：TRAE 关闭时运行（推荐）
#     · 拉取会覆盖本地 skills\、skill-config.json、plugin-config.json
#     · 如 TRAE 正在运行，可能无法即时生效，需重启 TRAE
#     · 建议：每天首次打开 TRAE 之前运行此脚本
#
#  ❌ 不需要开启 TRAE
#  ✅ 需要网络连接和 SSH 密钥配置
# ============================================================

$ErrorActionPreference = "Stop"
$SYNC_DIR = "$env:USERPROFILE\trae-sync"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TRAE 配置拉取 (Windows <- 从 GitHub)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 trae-sync 目录
if (!(Test-Path "$SYNC_DIR\.git")) {
    Write-Host "❌ 错误：$SYNC_DIR 仓库不存在" -ForegroundColor Red
    Write-Host "   请先运行 win-first-setup.ps1 进行首次设置" -ForegroundColor Yellow
    exit 1
}

# 检查 TRAE 是否在运行
$traeProcess = Get-Process -Name "Trae*","trae*" -ErrorAction SilentlyContinue
if ($traeProcess) {
    Write-Host "⚠️  警告：检测到 TRAE 可能正在运行" -ForegroundColor Yellow
    Write-Host "   拉取的配置可能无法即时生效，建议关闭 TRAE 后再运行" -ForegroundColor Yellow
    $confirm = Read-Host "是否继续？(y/N)"
    if ($confirm -notmatch "^[Yy]$") { exit 0 }
}

# 执行拉取
Write-Host "📥 正在拉取配置..." -ForegroundColor Green
Set-Location $SYNC_DIR
.\sync.ps1 pull

Write-Host ""
Write-Host "✅ 拉取完成！现在可以启动 TRAE 了。" -ForegroundColor Green
