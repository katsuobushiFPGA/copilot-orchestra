#!/usr/bin/env bash
# タスクごとに tmux ペインを開き、進捗ログをtailするスクリプト
# 使い方: ./scripts/tmux-task.sh <task-id> [コマンド]
#   コマンド省略時: そのタスクのログを tail -f する

set -euo pipefail

TASK_ID="${1:?タスクIDを指定してください}"
COMMAND="${2:-}"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
LOG_DIR="${PROJECT_ROOT}/.task-logs"
TASK_LOG="${LOG_DIR}/${TASK_ID}.log"

mkdir -p "$LOG_DIR"
touch "$TASK_LOG"

# tmux が起動していなければ何もしない
if [ -z "${TMUX:-}" ]; then
  echo "⚠️  tmux セッション外です。ログは ${TASK_LOG} に記録されます。"
  exit 0
fi

# デフォルトコマンド: ログを tail
if [ -z "$COMMAND" ]; then
  PANE_CMD="echo '📋 ${TASK_ID} の進捗ログ'; echo '━━━━━━━━━━━━━━━━━━━━'; tail -f ${TASK_LOG}"
else
  PANE_CMD="$COMMAND"
fi

# 新しいペインを開く（水平分割）
tmux split-window -h -t "${TMUX_PANE}" "$PANE_CMD"

# レイアウトを均等化
tmux select-layout tiled

echo "✅ ${TASK_ID} 用のペインを開きました"
