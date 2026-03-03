# AGENTS.md - Copilot CLI ワークフロー定義

## プロジェクトワークフロー

このプロジェクトでは、以下のワークフローに従ってタスクを管理・実行する。

### ワークフロー概要

```
orchestrator ──→ architect ──→ reviewer ──→ orchestrator ──→ developer×N
(要件整理)       (全体設計)     (設計レビュー)  (タスク分割)     (並列TDD実装)
                                                                  ↓
完了 ←── 人間レビュー ←── explainer ←── reviewer ←── 完了通知 ←──┘
         (承認/差戻)     (解説)       (コードレビュー)
```

### 使用エージェント

| エージェント | 役割 | タイミング |
|------------|------|-----------|
| `orchestrator` | フロー管理・要件整理・タスク分割 | 最初と中間（ステップ1, 4） |
| `architect` | 全体設計・技術選定・インターフェース定義 | 設計フェーズ（ステップ2） |
| `developer` | TDD 実装（Red→Green→Refactor） | 並列開発（ステップ5） |
| `reviewer` | 設計レビュー + コードレビュー | ステップ3, 7 |
| `explainer` | 人間向け解説（機能・仕組み・設計判断・トレードオフ） | 人間レビュー前（ステップ8） |

### 開始方法

1. **要件を伝える**: orchestrator エージェントに要件を伝える
2. **全体設計**: architect が技術選定・構造設計・インターフェース定義を行う
3. **設計レビュー**: reviewer が設計の妥当性を検証する
4. **タスク分割**: orchestrator がレビュー済み設計に基づきタスクを分割し `TASKS.md` に記録
5. **並列実行**: `/fleet` モードで developer エージェントが TDD で並列に実装する
6. **完了通知**: 各タスク完了時に通知
7. **コードレビュー**: reviewer がコードレビューする
8. **解説**: explainer が実装内容をわかりやすく解説する
9. **人間レビュー**: 解説を読んだ上で承認 or 差し戻し
10. **完了**: すべてのレビューを通過したタスクが `done` になる

### コマンド例

```
# devcontainer + tmux で起動
tmux new -s work
copilot

# fleet モードを有効にして並列開発
/fleet

# orchestrator エージェントでワークフローを開始
Use the orchestrator agent to break down and manage this task: [要件の説明]

# タスクの状態を確認
cat TASKS.md
```

### 通知設定

通知は以下の方法で送信される:
- **ターミナル出力**: 常に有効
- **デスクトップ通知**: `notify-send` が利用可能な場合
- **Webhook**: 環境変数 `NOTIFY_WEBHOOK_URL` を設定した場合（Slack等）

```bash
# Slack Webhook の例
export NOTIFY_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### タスク管理ルール

- すべてのタスクは `TASKS.md` で追跡する
- タスクは必ず「設計レビュー → コードレビュー → 人間レビュー」を通過すること
- 人間レビューは省略できない
- 差し戻しは何度でも可能
- 開発は TDD（テスト駆動開発）で行うこと
