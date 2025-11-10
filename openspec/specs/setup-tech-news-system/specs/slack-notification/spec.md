# Capability: Slack通知 (slack-notification)

## 説明
要約された記事をSlack Webhook経由で指定チャンネルに投稿する機能

## ADDED Requirements

### Requirement: Slack Webhook統合
Slack Incoming Webhookを使用してメッセージを投稿できなければならない (MUST)。

#### Scenario: 基本的なメッセージ投稿
**Given** 環境変数 `SLACK_WEBHOOK_URL` が設定されている
**When** 要約記事が投稿される
**Then** Slackチャンネルにメッセージが正常に配信される
**And** HTTPステータス200が返される

#### Scenario: Webhook URL未設定時のエラー処理
**Given** `SLACK_WEBHOOK_URL` が設定されていない
**When** 投稿が試みられる
**Then** 明確なエラーメッセージがログに記録される
**And** システムは起動時に設定検証で警告を出す

### Requirement: リッチフォーマットのサポート
Slackのブロックキットまたはマークダウンを使用して、読みやすい形式で投稿しなければならない (MUST)。

#### Scenario: フォーマット済み記事の投稿
**Given** 要約された記事データが利用可能
**When** Slackに投稿される
**Then** メッセージは以下を含む:
- 太字の記事タイトル
- 要約テキスト（通常フォーマット）
- 箇条書きのキーポイント
- リンク付きの「続きを読む」ボタンまたはリンク

#### Scenario: 複数記事のバッチ投稿
**Given** 5件の要約記事がある
**When** Slackへのバッチ投稿が実行される
**Then** 各記事が個別のメッセージまたはセクションとして投稿される
**And** 投稿間に適切な間隔（例: 1秒）が設けられる
**And** レート制限エラーが発生しない

### Requirement: エラーハンドリングとリトライ
ネットワークエラーやSlack側の一時的な障害に対応できなければならない (MUST)。

#### Scenario: 一時的なネットワークエラーからの回復
**Given** Slack APIが一時的に到達不能
**When** 投稿が失敗する
**Then** 最大3回までリトライされる
**And** リトライ間には指数バックオフ（1秒、2秒、4秒）が適用される

#### Scenario: Slackレート制限の処理
**Given** Slackから429（レート制限）レスポンスが返される
**When** 投稿が失敗する
**Then** `Retry-After` ヘッダーの値だけ待機する
**And** その後リトライが実行される

### Requirement: 投稿内容のバリデーション
不正または空のコンテンツは投稿されてはならない (MUST NOT)。

#### Scenario: 空の要約の除外
**Given** 一部の記事の要約が空または失敗している
**When** 投稿処理が実行される
**Then** 空の要約はスキップされる
**And** 警告がログに記録される
**And** 有効な要約のみが投稿される

### Requirement: 投稿結果のロギング
各投稿の成功/失敗が適切に記録されなければならない (MUST)。

#### Scenario: 投稿成功のログ記録
**Given** メッセージが正常に投稿された
**When** 投稿が完了する
**Then** ログに以下が記録される:
- 投稿時刻
- 投稿された記事のタイトル
- レスポンスステータス
- Webhook URL（機密部分はマスク）

#### Scenario: 投稿失敗のログ記録
**Given** メッセージ投稿が失敗した
**When** 全てのリトライが失敗する
**Then** エラーログに以下が記録される:
- エラー発生時刻
- 失敗した記事のタイトル
- エラーメッセージ
- HTTPステータスコード

## 関連Capability
- `content-summarization`: 要約データを入力として受け取る
