#!/usr/bin/env bash
# ============================================================
#  TRAE 配置拉取脚本 (Mac)
#  功能：从 GitHub 仓库拉取最新配置，覆盖本地 ~/.trae-cn/
# ============================================================
#
#  ⏰ 运行时机：TRAE 关闭时运行（推荐）
#     · 拉取会覆盖本地 skills/、skill-config.json、plugin-config.json
#     · 如 TRAE 正在运行，可能无法即时生效，需重启 TRAE
#     · 建议：每天首次打开 TRAE 之前运行此脚本
#
#  ❌ 不需要开启 TRAE
#  ✅ 需要网络连接和 SSH 密钥配置
# ============================================================

set -euo pipefail

SYNC_DIR="$HOME/trae-sync"

echo "=========================================="
echo "  TRAE 配置拉取 (Mac → 从 GitHub 拉取)"
echo "=========================================="
echo ""

# 检查 trae-sync 目录
if [ ! -d "$SYNC_DIR/.git" ]; then
  echo "❌ 错误：~/trae-sync 仓库不存在"
  echo "   请先运行首次设置：git clone <repo-url> ~/trae-sync"
  exit 1
fi

# 检查 TRAE 是否在运行
if pgrep -x "Trae" > /dev/null 2>&1 || pgrep -f "trae" > /dev/null 2>&1; then
  echo "⚠️  警告：检测到 TRAE 可能正在运行"
  echo "   拉取的配置可能无法即时生效，建议关闭 TRAE 后再运行"
  echo ""
  read -p "是否继续？(y/N) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# 启动 SSH agent
eval "$(ssh-agent -s)" 2>/dev/null
ssh-add ~/.ssh/id_ed25519 2>/dev/null || true

# 执行拉取
echo "📥 正在拉取配置..."
cd "$SYNC_DIR"
./sync.sh pull

echo ""
echo "✅ 拉取完成！现在可以启动 TRAE 了。"
