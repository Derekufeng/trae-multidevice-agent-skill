# ============================================================
#  TRAE 配置推送脚本 (Windows)
#  功能：将本地 ~/.trae-cn/ 配置推送到 GitHub 仓库
# ============================================================
#
#  ⏰ 运行时机：TRAE 关闭后运行（推荐）
#     · 推送本地 skills\、skill-config.json、plugin-config.json
#     · 如 TRAE 正在运行且正在写入配置，可能推送不完整的配置
#     · 建议：每天用完 TRAE 关闭后运行此脚本
#
#  ❌ 不需要开启 TRAE（建议关闭后运行）
#  ✅ 需要网络连接和 SSH 密钥配置
# ============================================================

$ErrorActionPreference = "Stop"
$SYNC_DIR = "$env:USERPROFILE\trae-sync"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TRAE 配置推送 (Windows -> 推送到 GitHub)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 trae-sync 目录
if (!(Test-Path "$SYNC_DIR\.git")) {
    Write-Host "❌ 错误：$SYNC_DIR 仓库不存在" -ForegroundColor Red
    Write-Host "   请先运行 win-first-setup.ps1 进行首次设置" -ForegroundColor Yellow
    exit 1
}

# 执行推送
Write-Host "📤 正在推送配置..." -ForegroundColor Green
Set-Location $SYNC_DIR
.\sync.ps1 push

Write-Host ""
Write-Host "✅ 推送完成！其他设备可以通过 pull 或 sync 获取最新配置。" -ForegroundColor Green
