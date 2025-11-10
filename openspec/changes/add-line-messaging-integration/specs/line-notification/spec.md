# Capability: LINE通知機能

## 概要
LINE Messaging APIを使用して、要約された技術ニュースをLINEグループまたはトークルームに配信する機能。

## ADDED Requirements

### Requirement: LINE Messaging APIクライアント実装
**ID**: REQ-LINE-001
**Priority**: High
**Component**: `TechNews::Notifiers::LineNotifier`

システムは、LINE Messaging APIを使用してメッセージを送信するクライアントを実装しなければならない (MUST)。クライアントは `/v2/bot/message/push` エンドポイントを使用し、適切なエラーハンドリングとリトライロジックを含むべきである (SHALL)。

#### Scenario: LINE APIへのメッセージ送信成功
**Given**: 有効なLINEアクセストークンとメッセージペイロードが設定されている
**When**: `notify(summary)` メソッドが呼び出される
**Then**: LINE Messaging APIの `/v2/bot/message/push` エンドポイントにPOSTリクエストが送信される
**And**: レスポンスが200 OKである
**And**: ログに成功メッセージが記録される

#### Scenario: LINE API認証エラー
**Given**: 無効なアクセストークンが設定されている
**When**: `notify(summary)` メソッドが呼び出される
**Then**: LINE APIから401エラーが返される
**And**: `NotifierError` 例外がスローされる
**And**: エラーログに認証失敗が記録される

#### Scenario: LINE APIレート制限エラー
**Given**: レート制限に達している
**When**: `notify(summary)` メソッドが呼び出される
**Then**: LINE APIから429エラーが返される
**And**: 指数バックオフでリトライが実行される
**And**: 最大3回までリトライする

---

### Requirement: Flex Messageフォーマッター
**ID**: REQ-LINE-002
**Priority**: High
**Component**: `TechNews::Notifiers::LineNotifier`

システムは、記事要約をLINE Flex Messageフォーマットに変換しなければならない (MUST)。メッセージには記事のタイトル、要約テキスト、ソース名、および記事URLへのアクションボタンを含むべきである (SHALL)。

#### Scenario: 記事要約のFlex Message変換
**Given**: 記事タイトル、要約テキスト、URL、ソース名を含むsummaryオブジェクト
**When**: `format_message(summary)` メソッドが呼び出される
**Then**: LINE Flex Messageフォーマットのハッシュが返される
**And**: タイトルがヘッダーブロックに含まれる
**And**: 要約テキストが本文ブロックに含まれる
**And**: 「記事を読む」ボタンアクションが含まれる
**And**: ソース名がフッターに含まれる

#### Scenario: 長いタイトルの切り詰め
**Given**: 100文字を超える記事タイトル
**When**: `format_message(summary)` メソッドが呼び出される
**Then**: タイトルが100文字に切り詰められる
**And**: 末尾に "..." が追加される

#### Scenario: URLエンコーディング
**Given**: 特殊文字を含むURL
**When**: `format_message(summary)` メソッドが呼び出される
**Then**: URLが適切にエンコードされる
**And**: ボタンアクションのURIフィールドに設定される

---

### Requirement: LINE設定バリデーション
**ID**: REQ-LINE-003
**Priority**: High
**Component**: `TechNews::Notifiers::LineNotifier`

システムは、LINE Messaging APIの設定値を初期化時にバリデーションしなければならない (MUST)。アクセストークンと送信先ID（User IDまたはGroup ID）が必須であり、欠落時には `ConfigurationError` 例外をスローすべきである (SHALL)。

#### Scenario: 有効なLINE設定でのインスタンス生成
**Given**: `TECH_NEWS_LINE_CHANNEL_ACCESS_TOKEN` 環境変数が設定されている
**And**: `TECH_NEWS_LINE_USER_ID` または `TECH_NEWS_LINE_GROUP_ID` が設定されている
**When**: `LineNotifier.new` が呼び出される
**Then**: インスタンスが正常に生成される
**And**: 設定値がインスタンス変数に保存される

#### Scenario: アクセストークンが未設定
**Given**: `TECH_NEWS_LINE_CHANNEL_ACCESS_TOKEN` が空または未設定
**When**: `LineNotifier.new` が呼び出される
**Then**: `ConfigurationError` 例外がスローされる
**And**: エラーメッセージに "LINE access token is required" が含まれる

#### Scenario: 送信先IDが未設定
**Given**: `TECH_NEWS_LINE_USER_ID` と `TECH_NEWS_LINE_GROUP_ID` が両方とも未設定
**When**: `LineNotifier.new` が呼び出される
**Then**: `ConfigurationError` 例外がスローされる
**And**: エラーメッセージに "LINE user_id or group_id is required" が含まれる

---

### Requirement: バッチ通知機能
**ID**: REQ-LINE-004
**Priority**: Medium
**Component**: `TechNews::Notifiers::LineNotifier`

システムは、複数の記事要約を順次LINEに送信する機能を提供しなければならない (MUST)。各送信の間には設定可能な待機時間を挿入し、レート制限を遵守すべきである (SHALL)。個別の送信エラーは他の送信を中断せず、最終的な成功数と失敗数を返却すべきである (SHALL)。

#### Scenario: 複数メッセージのバッチ送信
**Given**: 5件の記事要約の配列
**When**: `notify_batch(summaries)` メソッドが呼び出される
**Then**: 各要約に対して `notify` が順次呼び出される
**And**: 各送信の間に設定された待機時間（デフォルト2秒）が挿入される
**And**: 送信成功数と失敗数を含むハッシュが返される

#### Scenario: バッチ送信中の部分的なエラー
**Given**: 5件の記事要約があり、3件目の送信が失敗する
**When**: `notify_batch(summaries)` メソッドが呼び出される
**Then**: 1〜2件目は正常に送信される
**And**: 3件目はエラーをログに記録して続行する
**And**: 4〜5件目は正常に送信される
**And**: 戻り値が `{ posted: 4, failed: 1 }` となる

---

### Requirement: エラーハンドリングとリトライ
**ID**: REQ-LINE-005
**Priority**: High
**Component**: `TechNews::Notifiers::LineNotifier`

システムは、一時的なネットワークエラーやAPI障害に対して自動リトライ機能を提供しなければならない (MUST)。リトライは指数バックオフ戦略を使用し、最大3回まで実行すべきである (SHALL)。全てのリトライが失敗した場合は適切な例外をスローすべきである (SHALL)。

#### Scenario: ネットワークエラーでのリトライ
**Given**: 一時的なネットワークエラーが発生する
**When**: `notify(summary)` メソッドが呼び出される
**Then**: 指数バックオフ（2秒、4秒、8秒）でリトライする
**And**: 最大3回までリトライする
**And**: 各リトライの前に待機時間がある

#### Scenario: リトライ後の成功
**Given**: 最初の2回の送信が失敗し、3回目が成功する
**When**: `notify(summary)` メソッドが呼び出される
**Then**: 3回のリトライ後にメッセージが送信される
**And**: ログに "Retry successful" が記録される
**And**: 例外がスローされない

#### Scenario: リトライ上限後の失敗
**Given**: 3回とも送信が失敗する
**When**: `notify(summary)` メソッドが呼び出される
**Then**: `WebhookError` 例外がスローされる
**And**: エラーメッセージに "Failed after 3 retries" が含まれる

---

## Related Capabilities
- `multi-channel-notification`: 複数チャネル通知管理と統合
- `slack-notification`: 既存のSlack通知機能（アーキテクチャ参考）
