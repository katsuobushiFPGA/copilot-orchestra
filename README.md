# Copilot CLI 並列開発ワークフロー

Copilot CLI の autopilot + subagent 機能を活用した、設計→タスク分割→並列TDD開発→レビュー→完了のワークフローシステム。
devcontainer + tmux で安全かつ進捗が見える開発環境を提供します。

## 構成

```
.
├── AGENTS.md                        # ワークフロー定義（Copilot CLI が自動読み込み）
├── TASKS.md.template                # タスク管理テンプレート
├── .devcontainer/
│   ├── Dockerfile                   # tmux, git, curl, jq 入り Ubuntu ベース
│   ├── devcontainer.json            # GitHub CLI, Node.js, Copilot 設定
│   ├── tmux.conf                    # ペインタイトル表示・マウス操作対応
│   └── post-create.sh              # Copilot CLI インストール・初期設定
├── .github/
│   └── agents/
│       ├── orchestrator.md          # フロー管理（起点・タスク分割）
│       ├── architect.md             # 全体設計・技術選定
│       ├── developer.md             # TDD 実装
│       ├── reviewer.md              # 設計レビュー・コードレビュー
│       └── explainer.md             # 人間向け解説
└── scripts/
    ├── notify.sh                    # 完了通知（ターミナル/デスクトップ/Webhook）
    ├── tmux-task.sh                 # タスクごとの tmux ペイン作成
    └── task-log.sh                  # TDD 進捗ログ記録
```

## ワークフロー

```
 1. orchestrator    要件整理・指示
        ↓
 2. architect       全体設計（技術選定・構造・インターフェース定義）
        ↓
 3. reviewer        設計レビュー ←→ architect（差し戻し修正）
        ↓
 4. orchestrator    タスク分割 → TASKS.md に記録 → tmux ペイン作成
        ↓
 5. developer × N   並列 TDD 実装（Red→Green→Refactor）
        ↓
 6.                 完了通知
        ↓
 7. reviewer        コードレビュー ←→ developer（差し戻し修正）
        ↓
 8. explainer       人間向け解説（機能・仕組み・設計判断・トレードオフ）
        ↓
 9.                 人間レビュー（承認 or 差し戻し）
        ↓
10.                 完了 → 次タスクへ（ステップ5に戻る）
```

## 使い方

### 1. devcontainer でセットアップ

```bash
# VS Code で開く場合
# コマンドパレット → "Dev Containers: Reopen in Container"

# CLI で開く場合
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

### 2. tmux セッションを開始

```bash
tmux new -s work
```

### 3. Copilot CLI を起動

```bash
copilot

# fleet モードを有効化（並列サブエージェント）
/fleet
```

### 4. ワークフローを開始

```
Use the orchestrator agent to break down and implement:
ユーザー認証機能を実装してほしい。
ログイン、ログアウト、パスワードリセットの3つのAPIが必要。
```

### 5. 自動フロー

orchestrator が以下を自動で進行します:

1. **要件整理**: 不明点があれば質問してくれる
2. **全体設計**: architect が技術選定・構造・インターフェースを設計
3. **設計レビュー**: reviewer が設計の妥当性を検証
4. **タスク分割**: 設計に基づきタスクを分割、tmux ペインで進捗モニタ開始
5. **並列TDD開発**: developer エージェントが fleet モードで並列実装
6. **完了通知**: 各タスク完了時に通知
7. **コードレビュー**: reviewer が自動レビュー
8. **解説**: explainer が実装内容をわかりやすく解説
9. **人間レビュー依頼**: あなたにレビューを求めて一時停止
10. **完了**: 承認後、次のタスクへ自動で進行

### 6. 人間レビュー時の操作

explainer の解説を読んだ上で、Copilot があなたにレビューを求めます:

```
📖 T-001 の解説
🎯 何ができるようになったか: ...
🔧 どうやって実装したか: ...
💡 なぜこの方法を選んだか: ...
⚠️ 知っておくべきこと: ...

承認しますか？
> yes                              ← 承認
> no                               ← 却下（理由を次のプロンプトで入力）
> エラーハンドリングを追加して       ← 具体的な修正指示
> もう少し詳しく説明して            ← explainer に追加説明を依頼
```

### 7. 進捗の確認

tmux で各タスクの進捗がリアルタイムに表示されます:

```
┌─────────────────────┬──────────────────┬──────────────────┐
│ orchestrator (メイン) │ T-001 の進捗ログ  │ T-002 の進捗ログ  │
│                     │                  │                  │
│ > 設計完了           │ [15:01] 🔴 Red:  │ [15:01] 🔴 Red:  │
│ > タスク分割完了      │   ログインテスト   │   パスワード検証   │
│ > T-001, T-002 開始  │ [15:03] 🟢 Green │ [15:02] 🟢 Green │
│                     │   ログイン実装     │   検証ロジック実装  │
└─────────────────────┴──────────────────┴──────────────────┘
```

tmux 操作:
- **Alt + 矢印キー**: ペイン切り替え
- **マウスクリック**: ペイン選択

## エージェント一覧

| エージェント | 役割 | タイミング |
|------------|------|-----------|
| `orchestrator` | フロー管理・要件整理・タスク分割 | 最初と中間（ステップ1, 4） |
| `architect` | 全体設計・技術選定・インターフェース定義 | 設計フェーズ（ステップ2） |
| `developer` | TDD 実装（Red→Green→Refactor） | 並列開発（ステップ5） |
| `reviewer` | 設計レビュー + コードレビュー | ステップ3, 7 |
| `explainer` | 人間向け解説 | 人間レビュー前（ステップ8） |

## カスタマイズ

### 通知方法の追加

`scripts/notify.sh` を編集して通知先を追加できます:

- **Slack**: `NOTIFY_WEBHOOK_URL` 環境変数を設定
- **Discord**: Webhook URL を Discord 形式に変更
- **メール**: `mail` コマンドのセクションを追加

```bash
# Slack Webhook の例
export NOTIFY_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### エージェントのカスタマイズ

`.github/agents/` 配下の Markdown ファイルを編集して、各エージェントの振る舞いを調整できます。

### autopilot モードでの完全自動実行

人間レビューだけ手動にして、それ以外を完全自動で実行する場合:

```bash
# Shift+Tab で autopilot モードに切り替え
# または
copilot --autopilot --yolo --max-autopilot-continues 20 -p "要件の説明"
```

## タスクステータス

| ステータス | 意味 | 次のステータス |
|-----------|------|--------------|
| `pending` | 未着手 | `in-progress` |
| `in-progress` | 開発中 | `completed` |
| `completed` | 開発完了 | `ai-reviewed` or `needs-fix` |
| `ai-reviewed` | AIレビュー済 | `explained` or `needs-fix` |
| `explained` | 解説済 | `human-reviewed` |
| `human-reviewed` | 人間レビュー済 | `done` |
| `needs-fix` | 要修正 | `in-progress` |
| `done` | 完了 | - |
