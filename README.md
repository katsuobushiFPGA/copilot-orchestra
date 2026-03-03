# Copilot CLI 並列開発ワークフロー

Copilot CLI の autopilot + subagent 機能を活用した、タスク分割→並列開発→レビュー→完了のワークフローシステム。

## 構成

```
.
├── AGENTS.md                        # ワークフロー定義（Copilot CLI が自動読み込み）
├── TASKS.md.template                # タスク管理テンプレート
├── .github/
│   └── agents/
│       ├── orchestrator.md          # オーケストレーターエージェント
│       ├── developer.md             # 開発エージェント
│       └── reviewer.md              # レビューエージェント
└── scripts/
    └── notify.sh                    # 通知スクリプト
```

## ワークフロー

```
1. タスク分割 → 2. 並列開発 → 3. 完了通知 → 4. AIレビュー → 5. 人間レビュー → 6. 完了
       │              ↑              ↑            │                │
       │              └──────────────┘             │                │
       │              (差し戻し修正)                └────────────────┘
       └→ TASKS.md に記録
```

## 使い方

### 1. セットアップ

```bash
# プロジェクトディレクトリに移動
cd /path/to/your/project

# このワークフローシステムをコピー
cp -r .github/agents/ /path/to/your/project/.github/agents/
cp AGENTS.md /path/to/your/project/
cp -r scripts/ /path/to/your/project/
cp TASKS.md.template /path/to/your/project/TASKS.md

# (任意) Slack等への通知設定
export NOTIFY_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### 2. Copilot CLI を起動

```bash
copilot
```

### 3. ワークフローを開始

```
# fleet モードを有効化（並列サブエージェント）
/fleet

# orchestrator エージェントにタスクを依頼
Use the orchestrator agent to break down and implement: ユーザー認証機能を実装してほしい。
ログイン、ログアウト、パスワードリセットの3つのAPIが必要。
```

### 4. 自動フロー

orchestrator エージェントが以下を自動で行います:

1. **タスク分割**: 要件を独立したタスクに分割し `TASKS.md` に記録
2. **並列開発**: developer エージェントを fleet モードで並列起動
3. **完了通知**: 各タスク完了時に `scripts/notify.sh` で通知
4. **AIレビュー**: reviewer エージェントが自動レビュー
5. **人間レビュー依頼**: あなたにレビューを依頼（ターミナルで入力待ち）
6. **完了処理**: 承認後、タスクを `done` にして次へ

### 5. 人間レビュー時の操作

AIレビュー後、Copilot があなたにレビューを求めます:

```
🔍 AIレビュー完了: T-001
変更差分を確認してください。

承認しますか？ (yes/no/修正内容を記述)
> yes     ← 承認
> no      ← 却下（理由を次のプロンプトで入力）
> エラーハンドリングを追加して  ← 具体的な修正指示
```

## カスタマイズ

### 通知方法の追加

`scripts/notify.sh` を編集して通知先を追加できます:

- **Slack**: `NOTIFY_WEBHOOK_URL` 環境変数を設定
- **Discord**: Webhook URL を Discord 形式に変更
- **メール**: `mail` コマンドのセクションを追加

### エージェントのカスタマイズ

`.github/agents/` 配下の Markdown ファイルを編集して、各エージェントの振る舞いを調整できます。

### autopilot モードでの完全自動実行

AIレビューまでを完全自動で実行し、人間レビューだけ手動にする場合:

```bash
# autopilot モードで起動（人間レビューで一時停止）
# Shift+Tab で autopilot モードに切り替え
```

## タスクステータス

| ステータス | 意味 | 次のステータス |
|-----------|------|--------------|
| `pending` | 未着手 | `in-progress` |
| `in-progress` | 開発中 | `completed` |
| `completed` | 開発完了 | `ai-reviewed` or `needs-fix` |
| `ai-reviewed` | AIレビュー済 | `human-reviewed` or `needs-fix` |
| `human-reviewed` | 人間レビュー済 | `done` |
| `needs-fix` | 要修正 | `in-progress` |
| `done` | 完了 | - |
