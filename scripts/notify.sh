#!/usr/bin/env bash
# タスク完了通知スクリプト
# 使い方: ./scripts/notify.sh <task-id> <ステータス> [メッセージ]

set -euo pipefail

TASK_ID="${1:?タスクIDを指定してください}"
STATUS="${2:?ステータスを指定してください}"
MESSAGE="${3:-}"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 通知メッセージ組み立て
case "$STATUS" in
  completed)
    TITLE="✅ タスク完了: ${TASK_ID}"
    BODY="開発が完了しました。AIレビューを開始します。"
    ;;
  ai-reviewed)
    TITLE="🔍 AIレビュー完了: ${TASK_ID}"
    BODY="AIレビューが完了しました。人間レビューを待っています。"
    ;;
  human-reviewed)
    TITLE="👤 人間レビュー完了: ${TASK_ID}"
    BODY="人間レビューが承認されました。"
    ;;
  needs-fix)
    TITLE="🔧 修正依頼: ${TASK_ID}"
    BODY="レビューで問題が見つかりました。修正が必要です。"
    ;;
  done)
    TITLE="🎉 タスク完了: ${TASK_ID}"
    BODY="すべてのレビューが完了し、タスクが完了しました。"
    ;;
  *)
    TITLE="📋 ${TASK_ID}: ${STATUS}"
    BODY="${MESSAGE}"
    ;;
esac

[ -n "$MESSAGE" ] && BODY="${BODY} - ${MESSAGE}"

# --- 通知手段 ---

# 1. ターミナル出力（常に実行）
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${TITLE}"
echo "  ${BODY}"
echo "  [${TIMESTAMP}]"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 2. ターミナルベル
printf '\a'

# 3. デスクトップ通知（notify-send が利用可能な場合）
if command -v notify-send &>/dev/null; then
  notify-send "${TITLE}" "${BODY}" --urgency=normal 2>/dev/null || true
fi

# 4. ログファイルに記録
LOG_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.task-logs"
mkdir -p "$LOG_DIR"
echo "[${TIMESTAMP}] ${TITLE} | ${BODY}" >> "${LOG_DIR}/notifications.log"

# 5. Webhook通知（NOTIFY_WEBHOOK_URL が設定されている場合）
if [ -n "${NOTIFY_WEBHOOK_URL:-}" ]; then
  curl -s -X POST "${NOTIFY_WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"${TITLE}\n${BODY}\"}" \
    2>/dev/null || true
fi
