# Tasks: LINE Messaging API統合

## フェーズ1: アーキテクチャ準備とリファクタリング

### Task 1.1: Notifier基底クラスの作成
**Validates**: REQ-MULTI-001
**Dependencies**: なし
**Estimated effort**: 2時間

- [ ] `lib/tech_news/notifiers/base.rb` を作成
- [ ] 共通インターフェース (`notify`, `notify_batch`) を定義
- [ ] 共通ロジック（ログ記録、リトライ、エラーハンドリング）を実装
- [ ] RSpecでBase抽象クラスのテストを作成

**Verification**:
```bash
rspec spec/tech_news/notifiers/base_spec.rb
```

---

### Task 1.2: 既存NotifierをSlackNotifierにリファクタリング
**Validates**: REQ-MULTI-005
**Dependencies**: Task 1.1
**Estimated effort**: 3時間

- [ ] `lib/tech_news/notifiers/slack_notifier.rb` を作成
- [ ] `lib/tech_news/notifier.rb` のコードを移動し、`Notifiers::Base` を継承
- [ ] Slack固有のメッセージフォーマット処理を保持
- [ ] 既存テストを `spec/tech_news/notifiers/slack_notifier_spec.rb` に移動・更新
- [ ] 後方互換性を確認（既存の全テストが通過）

**Verification**:
```bash
rspec spec/tech_news/notifiers/slack_notifier_spec.rb
rspec spec/tech_news/orchestrator_spec.rb
```

---

### Task 1.3: Notifierファクトリの実装
**Validates**: REQ-MULTI-001
**Dependencies**: Task 1.2
**Estimated effort**: 2時間

- [ ] `lib/tech_news/notifiers/factory.rb` を作成
- [ ] 設定から有効な通知先タイプを読み取る
- [ ] 各通知先タイプに応じたNotifierインスタンスを生成
- [ ] 無効な通知先タイプの警告処理
- [ ] ファクトリのテストを作成

**Verification**:
```bash
rspec spec/tech_news/notifiers/factory_spec.rb
```

---

## フェーズ2: LINE Notifier実装

### Task 2.1: LINE Notifierクラスの基本実装
**Validates**: REQ-LINE-001, REQ-LINE-003
**Dependencies**: Task 1.1
**Estimated effort**: 4時間

- [ ] `lib/tech_news/notifiers/line_notifier.rb` を作成
- [ ] `Notifiers::Base` を継承
- [ ] LINE Channel Access Token、User ID/Group ID のバリデーション
- [ ] LINE Messaging API (`/v2/bot/message/push`) へのHTTP POSTクライアント実装
- [ ] Faradayを使ったHTTPクライアント設定（タイムアウト、ヘッダー）
- [ ] 基本的なエラーハンドリング（401, 429, 5xx）

**Verification**:
```bash
rspec spec/tech_news/notifiers/line_notifier_spec.rb --tag basic
```

---

### Task 2.2: Flex Messageフォーマッターの実装
**Validates**: REQ-LINE-002
**Dependencies**: Task 2.1
**Estimated effort**: 3時間

- [ ] `format_message` メソッドの実装
- [ ] Flex Message Bubble Containerの構築
- [ ] タイトル、本文、ソース、URLボタンのレイアウト
- [ ] 長いテキストの切り詰め処理（タイトル100文字、本文制限）
- [ ] URLの適切なエンコーディング処理

**Verification**:
```bash
rspec spec/tech_news/notifiers/line_notifier_spec.rb --tag formatter
```

---

### Task 2.3: リトライとエラーハンドリング
**Validates**: REQ-LINE-005
**Dependencies**: Task 2.1
**Estimated effort**: 2時間

- [ ] 指数バックオフでのリトライロジック（最大3回）
- [ ] ネットワークエラー時のリトライ
- [ ] レート制限（429）エラーのハンドリング
- [ ] 認証エラー（401）の適切な例外スロー
- [ ] サーバーエラー（5xx）の処理

**Verification**:
```bash
rspec spec/tech_news/notifiers/line_notifier_spec.rb --tag retry
```

---

### Task 2.4: バッチ通知機能の実装
**Validates**: REQ-LINE-004
**Dependencies**: Task 2.2, Task 2.3
**Estimated effort**: 2時間

- [ ] `notify_batch` メソッドの実装
- [ ] 複数メッセージの順次送信
- [ ] 各送信間の待機時間（デフォルト2秒、設定可能）
- [ ] 部分的なエラー時の継続処理
- [ ] 送信成功数・失敗数の集計と返却

**Verification**:
```bash
rspec spec/tech_news/notifiers/line_notifier_spec.rb --tag batch
```

---

## フェーズ3: Orchestrator統合

### Task 3.1: Configの複数通知先対応
**Validates**: REQ-MULTI-003
**Dependencies**: なし
**Estimated effort**: 2時間

- [ ] `lib/tech_news/config.rb` にLINE設定項目を追加
  - `line_channel_access_token`
  - `line_user_id` / `line_group_id`
  - `enabled_notifiers` (デフォルト: ["slack"])
- [ ] 環境変数のバリデーション追加
- [ ] `.env.example` にLINE関連の環境変数を追加
- [ ] Configテストの更新

**Verification**:
```bash
rspec spec/tech_news/config_spec.rb
```

---

### Task 3.2: Orchestratorの複数Notifier対応
**Validates**: REQ-MULTI-002, REQ-MULTI-004
**Dependencies**: Task 1.3, Task 3.1
**Estimated effort**: 3時間

- [ ] Orchestratorで複数Notifierインスタンスを保持
- [ ] Factoryを使ってNotifierを生成
- [ ] `publish_summaries` で全Notifierに配信
- [ ] 各Notifier別の送信結果を集約
- [ ] 通知先別のログ記録
- [ ] 一方の失敗が他方に影響しないエラーハンドリング
- [ ] 全通知先が失敗した場合の例外スロー

**Verification**:
```bash
rspec spec/tech_news/orchestrator_spec.rb
```

---

### Task 3.3: 複数通知先の結果レポート
**Validates**: REQ-MULTI-004
**Dependencies**: Task 3.2
**Estimated effort**: 1時間

- [ ] `report_results` メソッドに通知先別の結果表示を追加
- [ ] 各通知先の成功数・失敗数をログ出力
- [ ] 送信時間のパフォーマンス記録

**Verification**:
```bash
# 実際にdry-runモードで実行してログを確認
bundle exec ruby bin/tech_news --dry-run
```

---

## フェーズ4: テストとドキュメント

### Task 4.1: インテグレーションテストの作成
**Validates**: 全REQ
**Dependencies**: Task 3.2
**Estimated effort**: 3時間

- [ ] エンドツーエンドのインテグレーションテストを作成
- [ ] 複数通知先への配信フローのテスト
- [ ] モックを使ったLINE/Slack API呼び出しのテスト
- [ ] エラーシナリオのテスト（API障害、ネットワークエラー等）

**Verification**:
```bash
rspec spec/integration/multi_channel_notification_spec.rb
rspec # 全テストスイート
```

---

### Task 4.2: ドキュメント更新
**Validates**: 全REQ
**Dependencies**: Task 4.1
**Estimated effort**: 2時間

- [ ] README.md にLINE通知の設定手順を追加
- [ ] LINE Messaging APIのセットアップ手順を記載
- [ ] 環境変数の説明を更新
- [ ] 使用例とスクリーンショット（オプション）を追加
- [ ] トラブルシューティングセクションを追加

**Verification**:
手動でドキュメントをレビュー

---

### Task 4.3: GitHub Actionsワークフローの更新
**Validates**: REQ-MULTI-003
**Dependencies**: Task 4.2
**Estimated effort**: 1時間

- [ ] `.github/workflows/tech_news.yml` にLINE環境変数を追加（オプショナル）
- [ ] GitHub Secrets設定手順をドキュメントに追加
- [ ] ワークフローでの複数通知先テストの実行

**Verification**:
```bash
# GitHub Actionsで実行して正常動作を確認
```

---

## 並列化可能なタスク

以下のタスクは依存関係がないため並列実行可能:
- Task 1.1とTask 3.1は並列実行可能
- Task 2.1とTask 1.3は部分的に並列実行可能（2.1がBase完了後すぐ開始可能）

## 完了基準

全タスク完了時、以下が満たされていること:
- 全てのRSpecテストが通過（`rspec` コマンド）
- RuboCopの違反がない（`rubocop` コマンド）
- LINE通知とSlack通知が並行動作する
- 設定ファイルで通知先を柔軟に選択できる
- ドキュメントが最新の状態に更新されている
