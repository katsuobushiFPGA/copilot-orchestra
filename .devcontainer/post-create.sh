#!/usr/bin/env bash
set -euo pipefail

echo "🔧 セットアップ開始..."

# Copilot CLI インストール
if ! command -v copilot &>/dev/null; then
  echo "📦 Copilot CLI をインストール中..."
  npm install -g @anthropic-ai/copilot 2>/dev/null || \
  npm install -g @githubnext/github-copilot-cli 2>/dev/null || \
  echo "⚠️  Copilot CLI の自動インストールに失敗しました。手動でインストールしてください。"
fi

# スクリプトに実行権限
chmod +x scripts/*.sh 2>/dev/null || true

# .task-logs ディレクトリ作成
mkdir -p .task-logs

# git 設定
git config --global --add safe.directory /workspaces/$(basename "$PWD")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ セットアップ完了"
echo ""
echo "  使い方:"
echo "    1. tmux new -s work    ← tmux セッション開始"
echo "    2. copilot             ← Copilot CLI 起動"
echo "    3. /fleet              ← fleet モード有効化"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
