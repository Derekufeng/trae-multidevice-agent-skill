# ============================================================
#  TRAE 配置同步 - Windows 首次设置脚本
#  功能：克隆同步仓库 + 配置 SSH 密钥 + 首次拉取配置
# ============================================================
#
#  ⏰ 运行时机：Windows 首次使用 TRAE 前
#     · 在安装 TRAE 之前或首次启动之前运行
#     · 运行后 ~/.trae-cn/ 将拥有与 Mac 一致的配置
#
#  ❌ 不需要开启 TRAE
#  ✅ 需要已安装 Git for Windows
#  ✅ 需要已生成 SSH 密钥并添加到 GitHub
# ============================================================

$ErrorActionPreference = "Stop"

$REPO_URL = "git@github.com:Derekufeng/Traemd.git"
$SYNC_DIR = "$env:USERPROFILE\trae-sync"
$TRAE_HOME = "$env:USERPROFILE\.trae-cn"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TRAE 配置同步 - Windows 首次设置" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查 Git
Write-Host "[1/4] 检查 Git..." -ForegroundColor Yellow
$gitVersion = git --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Git 未安装，请先安装 Git for Windows: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ $gitVersion"

# 2. 检查 SSH 密钥
Write-Host "[2/4] 检查 SSH 密钥..." -ForegroundColor Yellow
$sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
if (!(Test-Path $sshKey)) {
    Write-Host "  📝 未找到 SSH 密钥，正在生成..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -C "trae-sync@$env:COMPUTERNAME" -f $sshKey -N '""'
    Write-Host ""
    Write-Host "  ⚠️  请将以下公钥添加到 GitHub (Settings → SSH Keys):" -ForegroundColor Yellow
    Get-Content "$sshKey.pub"
    Write-Host ""
    Write-Host "  添加完成后重新运行此脚本。" -ForegroundColor Yellow
    exit 0
}
Write-Host "  ✅ SSH 密钥已存在"

# 测试 GitHub 连接
Write-Host "  测试 GitHub SSH 连接..." -ForegroundColor Gray
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -notmatch "successfully authenticated") {
    Write-Host "  ❌ GitHub SSH 认证失败，请检查密钥是否已添加到 GitHub" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ GitHub SSH 连接正常"

# 3. 克隆同步仓库
Write-Host "[3/4] 克隆同步仓库..." -ForegroundColor Yellow
if (Test-Path $SYNC_DIR) {
    Write-Host "  ℹ️  $SYNC_DIR 已存在，跳过克隆" -ForegroundColor Gray
} else {
    git clone $REPO_URL $SYNC_DIR
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ 克隆失败，请检查仓库地址和网络" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ 仓库已克隆到 $SYNC_DIR"
}

# 4. 首次同步
Write-Host "[4/4] 首次同步配置..." -ForegroundColor Yellow
Set-Location $SYNC_DIR
.\sync.ps1 sync

Write-Host ""
Write-Host "✅ 首次设置完成！" -ForegroundColor Green
Write-Host "   配置已同步到 $TRAE_HOME" -ForegroundColor Gray
Write-Host "   现在可以安装/启动 TRAE 了" -ForegroundColor Gray
Write-Host ""
Write-Host "   日常使用：" -ForegroundColor Yellow
Write-Host "   · 任务前：.\win-pull.ps1（拉取其他设备的配置）" -ForegroundColor Gray
Write-Host "   · 任务后：.\win-push.ps1（推送本机配置到 GitHub）" -ForegroundColor Gray
