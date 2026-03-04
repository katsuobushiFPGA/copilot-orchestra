#!/usr/bin/env bash
# 人間レビュー確認スクリプト
# 使い方:
#   ./scripts/human-review.sh <task-id>        # 特定タスクをレビュー
#   ./scripts/human-review.sh --list           # レビュー待ちタスク一覧
#   ./scripts/human-review.sh --all            # 全レビュー待ちタスクを順にレビュー
#
# レビューフロー:
#   1. タスクの概要・変更内容・explainer の解説を表示
#   2. 承認 (approve) / 差し戻し (reject) / スキップを選択
#   3. TASKS.md を更新し、通知を送信
#   4. レビュー結果をログに記録

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
LOG_DIR="${PROJECT_ROOT}/.task-logs"
TASKS_FILE="${PROJECT_ROOT}/TASKS.md"
REVIEW_LOG="${LOG_DIR}/human-reviews.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$LOG_DIR"

# --- ユーティリティ ---
print_separator() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  printf '━%.0s' $(seq 1 "$cols")
  echo ""
}

colored() {
  local color="$1" text="$2"
  local code=""
  case "$color" in
    red)     code="\033[31m" ;;
    green)   code="\033[32m" ;;
    yellow)  code="\033[33m" ;;
    blue)    code="\033[34m" ;;
    cyan)    code="\033[36m" ;;
    bold)    code="\033[1m"  ;;
    *)       code="" ;;
  esac
  printf "${code}%s\033[0m" "$text"
}

# --- レビュー待ちタスク一覧 ---
list_pending_reviews() {
  if [ ! -f "$TASKS_FILE" ]; then
    echo "⚠️  TASKS.md が見つかりません"
    return 1
  fi

  local pending
  pending=$(grep -E '^\| T-[0-9].*ai-reviewed' "$TASKS_FILE" 2>/dev/null || true)

  if [ -z "$pending" ]; then
    echo ""
    colored green "✅ 人間レビュー待ちのタスクはありません"
    echo ""
    return 0
  fi

  echo ""
  colored bold "👤 人間レビュー待ちタスク一覧:"
  echo ""
  print_separator
  printf "  %-8s %-40s %-15s\n" "ID" "タスク" "ステータス"
  printf "  %-8s %-40s %-15s\n" "--------" "----------------------------------------" "---------------"

  echo "$pending" | while IFS='|' read -r _ id task status _ ; do
    id=$(echo "$id" | xargs)
    task=$(echo "$task" | xargs)
    status=$(echo "$status" | xargs)
    printf "  %-8s %-40s " "$id" "${task:0:40}"
    colored yellow "$status"
    echo ""
  done

  print_separator
  echo ""
  echo "  レビューするには: ./scripts/human-review.sh <task-id>"
  echo ""
}

# --- タスク詳細表示 ---
show_task_details() {
  local task_id="$1"

  echo ""
  print_separator
  colored bold "  👤 人間レビュー: ${task_id}"
  echo ""
  print_separator

  # TASKS.md からタスク情報を取得
  local task_line
  task_line=$(grep -E "^\| ${task_id} " "$TASKS_FILE" 2>/dev/null || true)
  if [ -z "$task_line" ]; then
    colored red "❌ タスク ${task_id} が TASKS.md に見つかりません"
    echo ""
    return 1
  fi

  local task_name task_status task_branch
  task_name=$(echo "$task_line" | awk -F'|' '{print $3}' | xargs)
  task_status=$(echo "$task_line" | awk -F'|' '{print $4}' | xargs)
  task_branch=$(echo "$task_line" | awk -F'|' '{print $5}' | xargs)

  echo ""
  echo "  タスク名   : ${task_name}"
  echo "  ステータス : ${task_status}"
  echo "  ブランチ   : ${task_branch}"
  echo ""

  # ステータスチェック
  if [ "$task_status" != "ai-reviewed" ]; then
    colored yellow "⚠️  このタスクのステータスは '${task_status}' です（ai-reviewed ではありません）"
    echo ""
    echo -n "  それでもレビューを続けますか？ [y/N] "
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
      echo "  レビューをスキップしました。"
      return 1
    fi
  fi

  # タスクログを表示
  local task_log="${LOG_DIR}/${task_id}.log"
  if [ -f "$task_log" ] && [ -s "$task_log" ]; then
    echo ""
    print_separator
    colored cyan "  📋 タスクログ:"
    echo ""
    echo ""
    cat "$task_log" | sed 's/^/    /'
    echo ""
  fi

  # worktree の変更差分を表示
  local worktree_path="${PROJECT_ROOT}/worktrees/${task_id}"
  if [ -d "$worktree_path" ]; then
    echo ""
    print_separator
    colored cyan "  📝 変更差分 (git diff):"
    echo ""
    echo ""
    (cd "$worktree_path" && git --no-pager diff --stat HEAD~1 2>/dev/null || echo "    (差分取得不可)") | sed 's/^/    /'
    echo ""
  fi

  # explainer の解説ファイルがある場合は表示
  local explain_file="${LOG_DIR}/${task_id}-explanation.md"
  if [ -f "$explain_file" ]; then
    echo ""
    print_separator
    colored cyan "  💡 Explainer の解説:"
    echo ""
    echo ""
    cat "$explain_file" | sed 's/^/    /'
    echo ""
  fi

  # レビュー結果ファイルがある場合は表示
  local review_file="${LOG_DIR}/${task_id}-review.md"
  if [ -f "$review_file" ]; then
    echo ""
    print_separator
    colored cyan "  🔍 AI レビュー結果:"
    echo ""
    echo ""
    cat "$review_file" | sed 's/^/    /'
    echo ""
  fi

  print_separator
  return 0
}

# --- レビュー実行 ---
do_review() {
  local task_id="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  show_task_details "$task_id" || return 1

  echo ""
  colored bold "  レビューの判断を選んでください:"
  echo ""
  echo "    [a] ✅ 承認 (approve)   — タスクを done にする"
  echo "    [r] 🔧 差し戻し (reject) — 修正を依頼する"
  echo "    [s] ⏭️  スキップ (skip)   — 後でレビューする"
  echo "    [q] 🚪 終了 (quit)       — レビューを中断する"
  echo ""

  while true; do
    echo -n "  選択 [a/r/s/q]: "
    read -r choice

    case "$choice" in
      a|A|approve)
        echo ""
        echo -n "  承認コメント（任意、Enter でスキップ）: "
        read -r comment

        # TASKS.md を更新
        update_task_status "$task_id" "human-reviewed"

        # レビューログに記録
        echo "[${timestamp}] ${task_id} | APPROVED | ${comment}" >> "$REVIEW_LOG"

        # タスクログに記録
        "$SCRIPT_DIR/task-log.sh" "$task_id" "👤 人間レビュー: 承認 ${comment:+— ${comment}}"

        # 通知
        "$SCRIPT_DIR/notify.sh" "$task_id" "human-reviewed" "${comment:-承認されました}"

        # done に更新
        update_task_status "$task_id" "done"
        "$SCRIPT_DIR/notify.sh" "$task_id" "done" "すべてのレビューを通過しました"

        echo ""
        colored green "  ✅ ${task_id} を承認しました"
        echo ""
        break
        ;;

      r|R|reject)
        echo ""
        echo -n "  差し戻し理由（必須）: "
        read -r reason
        while [ -z "$reason" ]; do
          echo -n "  理由を入力してください: "
          read -r reason
        done

        # TASKS.md を更新
        update_task_status "$task_id" "needs-fix"

        # レビューログに記録
        echo "[${timestamp}] ${task_id} | REJECTED | ${reason}" >> "$REVIEW_LOG"

        # タスクログに記録
        "$SCRIPT_DIR/task-log.sh" "$task_id" "👤 人間レビュー: 差し戻し — ${reason}"

        # 通知
        "$SCRIPT_DIR/notify.sh" "$task_id" "needs-fix" "${reason}"

        echo ""
        colored yellow "  🔧 ${task_id} を差し戻しました: ${reason}"
        echo ""
        break
        ;;

      s|S|skip)
        echo ""
        colored cyan "  ⏭️  ${task_id} のレビューをスキップしました"
        echo ""
        echo "[${timestamp}] ${task_id} | SKIPPED |" >> "$REVIEW_LOG"
        break
        ;;

      q|Q|quit)
        echo ""
        echo "  レビューを中断しました。"
        exit 0
        ;;

      *)
        colored red "  無効な選択です。a/r/s/q のいずれかを入力してください。"
        echo ""
        ;;
    esac
  done
}

# --- TASKS.md ステータス更新 ---
update_task_status() {
  local task_id="$1"
  local new_status="$2"

  if [ ! -f "$TASKS_FILE" ]; then
    echo "⚠️  TASKS.md が見つかりません"
    return 1
  fi

  # sed でステータスを更新 (| T-XXX | タスク名 | old-status | → | T-XXX | タスク名 | new-status |)
  sed -i "s/^\(| ${task_id} |[^|]*| *\)[^ |]*\( *|.*\)/\1${new_status}\2/" "$TASKS_FILE"
}

# --- メイン ---
case "${1:-}" in
  --list|-l)
    list_pending_reviews
    ;;

  --all|-a)
    if [ ! -f "$TASKS_FILE" ]; then
      echo "⚠️  TASKS.md が見つかりません"
      exit 1
    fi

    pending_ids=$(grep -E '^\| T-[0-9].*ai-reviewed' "$TASKS_FILE" 2>/dev/null \
      | awk -F'|' '{print $2}' | xargs -n1 2>/dev/null || true)

    if [ -z "$pending_ids" ]; then
      colored green "✅ 人間レビュー待ちのタスクはありません"
      echo ""
      exit 0
    fi

    for tid in $pending_ids; do
      do_review "$tid"
    done

    echo ""
    colored green "✅ 全タスクのレビューが完了しました"
    echo ""
    ;;

  --help|-h)
    echo "使い方:"
    echo "  ./scripts/human-review.sh <task-id>   特定タスクをレビュー"
    echo "  ./scripts/human-review.sh --list      レビュー待ちタスク一覧"
    echo "  ./scripts/human-review.sh --all       全レビュー待ちタスクを順にレビュー"
    echo "  ./scripts/human-review.sh --help      このヘルプを表示"
    ;;

  "")
    echo "❌ タスクIDまたはオプションを指定してください"
    echo "   ./scripts/human-review.sh --help でヘルプを表示"
    exit 1
    ;;

  *)
    do_review "$1"
    ;;
esac
