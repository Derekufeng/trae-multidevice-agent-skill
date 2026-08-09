#!/usr/bin/env bash
# ============================================================
#  TRAE 配置推送脚本 (Mac)
#  功能：将本地 ~/.trae-cn/ 配置推送到 GitHub 仓库
# ============================================================
#
#  ⏰ 运行时机：TRAE 关闭后运行（推荐）
#     · 推送本地 skills/、skill-config.json、plugin-config.json
#     · 如 TRAE 正在运行且正在写入配置，可能推送不完整的配置
#     · 建议：每天用完 TRAE 关闭后运行此脚本
#
#  ❌ 不需要开启 TRAE（建议关闭后运行）
#  ✅ 需要网络连接和 SSH 密钥配置
# ============================================================

set -euo pipefail

SYNC_DIR="$HOME/trae-sync"

echo "=========================================="
echo "  TRAE 配置推送 (Mac → 推送到 GitHub)"
echo "=========================================="
echo ""

# 检查 trae-sync 目录
if [ ! -d "$SYNC_DIR/.git" ]; then
  echo "❌ 错误：~/trae-sync 仓库不存在"
  echo "   请先运行首次设置：git clone <repo-url> ~/trae-sync"
  exit 1
fi

# 启动 SSH agent
eval "$(ssh-agent -s)" 2>/dev/null
ssh-add ~/.ssh/id_ed25519 2>/dev/null || true

# 执行推送
echo "📤 正在推送配置..."
cd "$SYNC_DIR"
./sync.sh push

echo ""
echo "✅ 推送完成！其他设备可以通过 pull 或 sync 获取最新配置。"
