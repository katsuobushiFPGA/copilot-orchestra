#!/usr/bin/env bash
# タスクのログファイルに書き込むユーティリティ
# 使い方: ./scripts/task-log.sh <task-id> <メッセージ>

set -euo pipefail

TASK_ID="${1:?タスクIDを指定してください}"
shift
MESSAGE="$*"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
LOG_DIR="${PROJECT_ROOT}/.task-logs"
TASK_LOG="${LOG_DIR}/${TASK_ID}.log"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%H:%M:%S')
echo "[${TIMESTAMP}] ${MESSAGE}" >> "$TASK_LOG"
