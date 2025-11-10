# Capability: スケジュール実行 (scheduled-execution)

## 説明
GitHub Actionsを使用してシステムを定期的に自動実行する機能

## ADDED Requirements

### Requirement: Cron-based定期実行
GitHub Actionsのcronトリガーを使用して、設定されたスケジュールで実行されなければならない (MUST)。

#### Scenario: 日次実行の設定
**Given** GitHub Actionsワークフローが設定されている
**When** cron式 `0 9 * * *` (UTC 9:00, JST 18:00) が設定される
**Then** 毎日指定時刻にワークフローが自動実行される
**And** 全プロセス（収集→要約→投稿）が順次実行される

#### Scenario: 手動トリガーのサポート
**Given** ワークフローに `workflow_dispatch` が設定されている
**When** GitHubのActionsタブから手動実行が選択される
**Then** 即座にワークフローが起動する
**And** 通常のcron実行と同じプロセスが実行される

### Requirement: 環境変数の安全な管理
機密情報（APIキー、Webhook URL）はGitHub Secretsで管理されなければならない (MUST)。

#### Scenario: Secretsからの環境変数読み込み
**Given** 以下のSecretsが設定されている:
- `ANTHROPIC_API_KEY`
- `SLACK_WEBHOOK_URL`
**When** ワークフローが実行される
**Then** これらの値が環境変数として利用可能になる
**And** ログには機密情報が表示されない

### Requirement: Ruby環境のセットアップ
最新の安定版Rubyと必要なgemが自動的にインストールされなければならない (MUST)。

#### Scenario: Ruby環境の構築
**Given** `Gemfile` が定義されている
**When** ワークフローが実行される
**Then** 指定されたRubyバージョン（最新安定版）がセットアップされる
**And** `bundle install` が実行される
**And** 全ての依存関係が正常にインストールされる

### Requirement: 実行時間の制限
GitHub Actions無料枠を考慮し、実行時間が適切に管理されなければならない (MUST)。

#### Scenario: タイムアウト設定
**Given** ワークフローにタイムアウトが設定されている（例: 10分）
**When** 処理が異常に長時間実行される
**Then** 設定時間に達した時点でジョブが強制終了される
**And** 失敗通知が記録される

#### Scenario: 効率的な実行
**Given** 通常の実行ケース
**When** 全プロセスが実行される
**Then** 合計実行時間が5分以内に収まる
**And** 無駄な待機時間がない

### Requirement: 実行結果の通知
ワークフローの成功/失敗が適切に記録され、必要に応じて通知されなければならない (MUST)。

#### Scenario: 成功時のログ記録
**Given** ワークフローが正常に完了した
**When** 全プロセスが成功する
**Then** GitHub Actionsログに以下が記録される:
- 収集した記事数
- 要約生成の成功/失敗数
- Slack投稿の成功数
- 合計実行時間

#### Scenario: 失敗時のエラー通知
**Given** ワークフロー実行中にエラーが発生した
**When** 重大なエラー（例: API認証失敗）が起きる
**Then** ワークフローステータスが "failed" になる
**And** 詳細なエラーログが記録される
**And** GitHub Actionsの通知機能でエラーが通知される

### Requirement: キャッシュの活用
依存関係のインストール時間を短縮するため、gemをキャッシュしなければならない (MUST)。

#### Scenario: Gemキャッシュの利用
**Given** 前回の実行でgemがインストールされた
**When** 次回のワークフローが実行される
**Then** キャッシュされたgemが復元される
**And** `bundle install` の実行時間が大幅に短縮される（初回実行の30%以下）

## 関連Capability
- `news-collection`: 実行の最初のステップとして呼び出される
- `content-summarization`: 収集後に呼び出される
- `slack-notification`: 最終ステップとして呼び出される
