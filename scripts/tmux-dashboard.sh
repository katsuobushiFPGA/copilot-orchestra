#!/usr/bin/env bash
# tmux ダッシュボード: 全タスクの進捗を一覧表示するスクリプト
# 使い方:
#   ./scripts/tmux-dashboard.sh          # 現在のペインで表示
#   ./scripts/tmux-dashboard.sh --pane   # 新しい tmux ペインで開く
#   ./scripts/tmux-dashboard.sh --watch  # 自動更新モード（2秒ごと）
#
# ダッシュボードには以下が表示される:
#   - TASKS.md のタスク一覧とステータス
#   - 各タスクの最新ログエントリ
#   - 通知ログの最新エントリ

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
LOG_DIR="${PROJECT_ROOT}/.task-logs"
TASKS_FILE="${PROJECT_ROOT}/TASKS.md"

MODE="${1:-}"

# --- tmux ペインで開くモード ---
if [ "$MODE" = "--pane" ]; then
  if [ -z "${TMUX:-}" ]; then
    echo "⚠️  tmux セッション外です。--pane オプションは tmux 内でのみ使えます。"
    echo "   代わりに直接実行するか --watch を使ってください。"
    exit 1
  fi
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  tmux split-window -h -t "${TMUX_PANE}" "bash ${SCRIPT_PATH} --watch"
  tmux select-layout tiled
  echo "✅ ダッシュボードペインを開きました"
  exit 0
fi

# --- ダッシュボード描画関数 ---
render_dashboard() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local separator
  separator=$(printf '━%.0s' $(seq 1 "$cols"))

  # パイプ経由でない場合のみ clear
  if [ -t 1 ]; then
    clear
  fi
  echo ""
  echo "  📊 タスク進捗ダッシュボード"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "$separator"

  # --- TASKS.md のステータス表示 ---
  if [ -f "$TASKS_FILE" ]; then
    echo ""
    echo "  ■ タスクステータス"
    echo ""

    # ヘッダー行を表示
    printf "  %-8s %-30s %-15s %-12s\n" "ID" "タスク" "ステータス" "ブランチ"
    printf "  %-8s %-30s %-15s %-12s\n" "--------" "------------------------------" "---------------" "------------"

    # TASKS.md からタスク行を抽出して表示
    grep -E '^\| T-[0-9]' "$TASKS_FILE" 2>/dev/null | while IFS='|' read -r _ id task status branch _ ; do
      id=$(echo "$id" | xargs)
      task=$(echo "$task" | xargs)
      status=$(echo "$status" | xargs)
      branch=$(echo "$branch" | xargs)

      # ステータスに応じた色付け
      local color_code=""
      local reset="\033[0m"
      case "$status" in
        pending)         color_code="\033[37m" ;;  # 白
        in-progress)     color_code="\033[33m" ;;  # 黄
        completed)       color_code="\033[36m" ;;  # シアン
        ai-reviewed)     color_code="\033[34m" ;;  # 青
        human-reviewed)  color_code="\033[35m" ;;  # マゼンタ
        done)            color_code="\033[32m" ;;  # 緑
        needs-fix)       color_code="\033[31m" ;;  # 赤
        *)               color_code="" ;;
      esac

      printf "  %-8s %-30s ${color_code}%-15s${reset} %-12s\n" \
        "$id" "${task:0:30}" "$status" "$branch"
    done

    # サマリー
    echo ""
    local total pending in_prog completed reviewed done needs_fix
    total=$(grep -cE '^\| T-[0-9]' "$TASKS_FILE" 2>/dev/null || true)
    pending=$(grep -cE '^\| T-[0-9].*pending' "$TASKS_FILE" 2>/dev/null || true)
    in_prog=$(grep -cE '^\| T-[0-9].*in-progress' "$TASKS_FILE" 2>/dev/null || true)
    completed=$(grep -cE '^\| T-[0-9].*(completed|ai-reviewed)' "$TASKS_FILE" 2>/dev/null || true)
    reviewed=$(grep -cE '^\| T-[0-9].*human-reviewed' "$TASKS_FILE" 2>/dev/null || true)
    done=$(grep -cE '^\| T-[0-9].*done' "$TASKS_FILE" 2>/dev/null || true)
    needs_fix=$(grep -cE '^\| T-[0-9].*needs-fix' "$TASKS_FILE" 2>/dev/null || true)

    # 空文字を0に変換
    total=${total:-0}; pending=${pending:-0}; in_prog=${in_prog:-0}
    completed=${completed:-0}; reviewed=${reviewed:-0}; done=${done:-0}
    needs_fix=${needs_fix:-0}

    printf "  📈 合計: %d | 未着手: %d | 開発中: %d | レビュー中: %d | レビュー済: %d | 完了: %d" \
      "$total" "$pending" "$in_prog" "$completed" "$reviewed" "$done"
    if [ "$needs_fix" -gt 0 ]; then
      printf " | \033[31m要修正: %d\033[0m" "$needs_fix"
    fi
    echo ""
  else
    echo ""
    echo "  ⚠️  TASKS.md が見つかりません"
  fi

  echo "$separator"

  # --- 各タスクの最新ログ ---
  echo ""
  echo "  ■ タスクログ（最新エントリ）"
  echo ""

  mkdir -p "$LOG_DIR"
  local has_logs=false
  for logfile in "$LOG_DIR"/T-*.log; do
    [ -f "$logfile" ] || continue
    has_logs=true
    local task_id
    task_id=$(basename "$logfile" .log)
    local last_line
    last_line=$(tail -1 "$logfile" 2>/dev/null || echo "(ログなし)")
    printf "  \033[36m%-8s\033[0m %s\n" "$task_id" "$last_line"
  done

  if [ "$has_logs" = false ]; then
    echo "  (タスクログなし)"
  fi

  echo ""
  echo "$separator"

  # --- 通知ログの最新5件 ---
  echo ""
  echo "  ■ 通知ログ（最新5件）"
  echo ""

  local notif_log="${LOG_DIR}/notifications.log"
  if [ -f "$notif_log" ] && [ -s "$notif_log" ]; then
    tail -5 "$notif_log" | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (通知ログなし)"
  fi

  echo ""
  echo "$separator"

  # --- 人間レビュー待ちタスクの強調表示 ---
  if [ -f "$TASKS_FILE" ]; then
    local awaiting
    awaiting=$(grep -E '^\| T-[0-9].*ai-reviewed' "$TASKS_FILE" 2>/dev/null || true)
    if [ -n "$awaiting" ]; then
      echo ""
      printf "  \033[33;1m⚠️  人間レビュー待ちタスクがあります:\033[0m\n"
      echo "$awaiting" | while IFS='|' read -r _ id task _ ; do
        id=$(echo "$id" | xargs)
        task=$(echo "$task" | xargs)
        printf "     → \033[33m%s\033[0m: %s\n" "$id" "$task"
      done
      echo "     実行: ./scripts/human-review.sh <task-id>"
      echo ""
    fi
  fi
}

# --- 実行 ---
if [ "$MODE" = "--watch" ]; then
  # 自動更新モード
  trap 'echo "ダッシュボードを終了します"; exit 0' INT TERM
  while true; do
    render_dashboard
    echo "  [Ctrl+C で終了 | 2秒ごとに自動更新]"
    sleep 2
  done
else
  # ワンショット表示
  render_dashboard
fi
