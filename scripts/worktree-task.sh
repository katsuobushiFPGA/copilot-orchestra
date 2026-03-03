#!/usr/bin/env bash
# タスクごとの git worktree を作成/再利用するユーティリティ
# 使い方: ./scripts/worktree-task.sh <task-id>

set -euo pipefail

TASK_ID="${1:?タスクIDを指定してください (例: T-001)}"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$PROJECT_ROOT" ]; then
  echo "❌ Gitリポジトリ内で実行してください。"
  exit 1
fi

WORKTREE_BASE="${PROJECT_ROOT}/worktrees"
WORKTREE_PATH="${WORKTREE_BASE}/${TASK_ID}"
BRANCH_NAME="task/${TASK_ID}"

mkdir -p "$WORKTREE_BASE"

# 既存worktreeの再利用
if [ -d "$WORKTREE_PATH" ] && [ -n "$(git -C "$PROJECT_ROOT" worktree list --porcelain | awk '/^worktree / {print $2}' | grep -Fx "$WORKTREE_PATH" || true)" ]; then
  echo "🔁 既存worktreeを再利用します"
  echo "   task    : ${TASK_ID}"
  echo "   branch  : ${BRANCH_NAME}"
  echo "   path    : ${WORKTREE_PATH}"
  printf '%s\n' "$WORKTREE_PATH"
  exit 0
fi

# worktreeはないがブランチが存在する場合はそのブランチで作成
if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
  git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

echo "✅ worktreeを準備しました"
echo "   task    : ${TASK_ID}"
echo "   branch  : ${BRANCH_NAME}"
echo "   path    : ${WORKTREE_PATH}"

# 呼び出し元が利用しやすいよう最後にパスを出力
printf '%s\n' "$WORKTREE_PATH"
