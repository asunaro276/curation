# Tasks: 技術ニュース自動収集・配信システム

## Phase 1: プロジェクト基盤構築

### Task 1.1: プロジェクト構造のセットアップ
- [ ] Rubyプロジェクトの初期化（`bundle init`）
- [ ] ディレクトリ構造の作成（`lib/`, `config/`, `spec/`）
- [ ] Gemfileの作成と基本的な依存関係の追加
  - `anthropic` (Claude API)
  - `faraday` (HTTPクライアント)
  - `rss` (RSS解析)
  - `nokogiri` (HTML解析)
  - `rspec` (テストフレームワーク)
- [ ] `.gitignore` の作成（`.env`, `*.gem`, `vendor/` 等）
- [ ] `README.md` の作成（プロジェクト概要、セットアップ手順）

**検証**: `bundle install` が成功し、基本的なディレクトリ構造が存在する

**依存関係**: なし（開始タスク）

---

### Task 1.2: 設定管理の実装
- [ ] `config/sources.yml` の作成（ニュースソース定義）
- [ ] `lib/tech_news/config.rb` の実装
  - 環境変数読み込み（`ANTHROPIC_API_KEY`, `SLACK_WEBHOOK_URL`）
  - `sources.yml` のパース
  - 設定検証ロジック
- [ ] `.env.example` の作成（必須環境変数の例）
- [ ] 設定クラスのユニットテスト作成

**検証**:
- 設定が正常に読み込まれる
- 環境変数未設定時に適切なエラーが発生する
- テストが全て通過する

**依存関係**: Task 1.1

---

### Task 1.3: ロギングとエラーハンドリングの実装
- [ ] `lib/tech_news/logger.rb` の実装
  - 標準出力への構造化ログ
  - ログレベル設定（DEBUG, INFO, WARN, ERROR）
  - 機密情報マスキング機能
- [ ] カスタムエラークラスの定義
  - `CollectorError`
  - `SummarizerError`
  - `NotifierError`
- [ ] ロガーのユニットテスト作成

**検証**:
- ログが適切にフォーマットされる
- 機密情報（APIキー等）がマスクされる
- テストが通過する

**依存関係**: Task 1.1

---

## Phase 2: コアコンポーネント実装

### Task 2.1: 記事データモデルの定義
- [ ] `lib/tech_news/models/article.rb` の実装
  - `Article` Structの定義（title, url, published_at, description, source, metadata）
  - バリデーションメソッド（必須フィールドチェック）
- [ ] データモデルのユニットテスト作成

**検証**:
- Articleインスタンスが正常に作成される
- バリデーションが機能する
- テストが通過する

**依存関係**: Task 1.1

---

### Task 2.2: ベースCollectorの実装
- [ ] `lib/tech_news/collectors/base.rb` の実装
  - 抽象メソッド定義（`fetch`, `parse`）
  - エラーハンドリング
  - タイムアウト設定
- [ ] HTTPヘルパーメソッドの実装（User-Agent設定等）
- [ ] ベースクラスのテスト作成

**検証**:
- 派生クラスで必須メソッドの実装が強制される
- タイムアウトが機能する
- テストが通過する

**依存関係**: Task 2.1, Task 1.3

---

### Task 2.3: RSSCollectorの実装
- [ ] `lib/tech_news/collectors/rss_collector.rb` の実装
  - RSSフィードの取得
  - RSS/Atomフォーマットのパース
  - Article構造体への変換
- [ ] RSSCollectorの統合テスト作成（モックフィード使用）

**検証**:
- 有効なRSSフィードから記事を取得できる
- 不正なフィードでエラーが適切に処理される
- テストが通過する

**依存関係**: Task 2.2

---

### Task 2.4: GitHub Trending Collectorの実装
- [ ] `lib/tech_news/collectors/github_trending_collector.rb` の実装
  - GitHub Trending APIまたはスクレイピング
  - リポジトリ情報の取得
  - Article形式への変換
- [ ] GitHub Collectorのテスト作成

**検証**:
- トレンドリポジトリを取得できる
- レート制限が適切に処理される
- テストが通過する

**依存関係**: Task 2.2

---

### Task 2.5: CollectorFactoryの実装
- [ ] `lib/tech_news/collectors/factory.rb` の実装
  - 設定に基づいてコレクターインスタンスを生成
  - サポートされていないタイプのエラー処理
- [ ] Factoryのユニットテスト作成

**検証**:
- 設定からコレクターが正しく生成される
- 無効なタイプで適切にエラーが発生する
- テストが通過する

**依存関係**: Task 2.3, Task 2.4

---

### Task 2.6: Summarizerの実装
- [ ] `lib/tech_news/summarizer.rb` の実装
  - Claude APIクライアントの初期化
  - `summarize(article)` メソッド
  - プロンプト構築ロジック
  - トークン数制限（truncate_content）
  - エラーハンドリングとリトライ（exponential backoff）
- [ ] Summarizerのユニットテスト作成（APIモック使用）

**検証**:
- Claude APIが正常に呼び出される
- 長文記事が適切に切り詰められる
- リトライロジックが機能する
- テストが通過する

**依存関係**: Task 1.2, Task 1.3

---

### Task 2.7: Summarizerのバッチ処理実装
- [ ] `summarize_batch(articles)` メソッドの実装
  - レート制限対策の待機時間
  - 部分的な失敗の処理（継続実行）
  - 進捗ログ
- [ ] バッチ処理の統合テスト作成

**検証**:
- 複数記事が順次処理される
- 一部の失敗が全体を止めない
- レート制限エラーが発生しない
- テストが通過する

**依存関係**: Task 2.6

---

### Task 2.8: Notifierの実装
- [ ] `lib/tech_news/notifier.rb` の実装
  - Slack Webhook URLの検証
  - `notify(summary)` メソッド
  - Slackメッセージフォーマット構築（Block Kit）
  - HTTPリクエスト送信
  - エラーハンドリングとリトライ
- [ ] Notifierのユニットテスト作成（Webhook APIモック）

**検証**:
- Slackメッセージが正しくフォーマットされる
- リトライロジックが機能する
- 429レスポンスが適切に処理される
- テストが通過する

**依存関係**: Task 1.2, Task 1.3

---

### Task 2.9: Notifierのバッチ投稿実装
- [ ] `notify_batch(summaries)` メソッドの実装
  - 投稿間隔の設定（1秒待機）
  - 部分的な失敗の処理
  - 投稿結果のログ記録
- [ ] バッチ投稿の統合テスト作成

**検証**:
- 複数メッセージが間隔を空けて投稿される
- レート制限エラーが発生しない
- テストが通過する

**依存関係**: Task 2.8

---

## Phase 3: オーケストレーションと統合

### Task 3.1: Orchestratorの実装
- [ ] `lib/tech_news/orchestrator.rb` の実装
  - 全コンポーネントの初期化
  - `run` メソッド（メインワークフロー）
  - 各フェーズの実行と結果集約
  - 全体的なエラーハンドリング
- [ ] Orchestratorの統合テスト作成

**検証**:
- 全プロセスが順次実行される
- エラーが適切に伝播・処理される
- テストが通過する

**依存関係**: Task 2.5, Task 2.7, Task 2.9

---

### Task 3.2: CLIエントリーポイントの作成
- [ ] `bin/run` の作成（実行可能スクリプト）
  - 引数パース（オプション: `--dry-run`, `--verbose`）
  - Orchestratorの起動
  - 実行結果サマリーの表示
- [ ] CLIのマニュアルテスト

**検証**:
- `./bin/run` で正常に実行される
- `--dry-run` でAPI呼び出しがスキップされる
- 実行結果が読みやすく表示される

**依存関係**: Task 3.1

---

### Task 3.3: 統合テストの作成
- [ ] エンドツーエンドテストの実装
  - モックデータを使った全フロー検証
  - 各フェーズの入出力確認
- [ ] エッジケーステストの追加
  - 全ソースが失敗する場合
  - API制限超過の場合
  - ネットワークエラーの場合

**検証**:
- 全統合テストが通過する
- エッジケースが適切に処理される

**依存関係**: Task 3.2

---

## Phase 4: GitHub Actions自動化

### Task 4.1: GitHub Actionsワークフローの作成
- [ ] `.github/workflows/run-curation.yml` の作成
  - cron設定（日次実行: `0 9 * * *`）
  - `workflow_dispatch` トリガー追加（手動実行）
  - Rubyセットアップステップ
  - 依存関係インストール（`bundle install`）
  - メインスクリプト実行
- [ ] ワークフローのテスト（手動トリガー）

**検証**:
- 手動実行が成功する
- 全ステップが正常に完了する
- ログが適切に記録される

**依存関係**: Task 3.2

---

### Task 4.2: GitHub Secretsの設定
- [ ] 必須Secretsのドキュメント作成
  - `ANTHROPIC_API_KEY`
  - `SLACK_WEBHOOK_URL`
- [ ] Secretsの設定手順をREADMEに追加
- [ ] ワークフローでのSecrets利用確認

**検証**:
- Secretsが環境変数として利用可能
- ログに機密情報が露出しない

**依存関係**: Task 4.1

---

### Task 4.3: ワークフロー最適化
- [ ] Gemキャッシュの設定（`actions/cache`）
- [ ] タイムアウト設定（10分）
- [ ] 失敗通知の設定（GitHub Actions通知）
- [ ] 実行時間の計測とログ記録

**検証**:
- 2回目以降の実行が高速化される（キャッシュ効果）
- タイムアウトが機能する
- 失敗時に適切に通知される

**依存関係**: Task 4.2

---

## Phase 5: ドキュメントと最終調整

### Task 5.1: READMEの完成
- [ ] プロジェクト概要
- [ ] セットアップ手順（詳細）
- [ ] 環境変数の説明
- [ ] 使い方（ローカル実行、GitHub Actions）
- [ ] トラブルシューティング

**検証**:
- 新規ユーザーがREADMEに従ってセットアップできる

**依存関係**: Task 4.3

---

### Task 5.2: 設定ファイルのサンプル追加
- [ ] `config/sources.example.yml` の作成
  - 複数ソースの例
  - コメント付き説明
- [ ] `.env.example` の更新（全環境変数）

**検証**:
- サンプルファイルがコピーして使用できる

**依存関係**: なし（並列可能）

---

### Task 5.3: コードレビューとリファクタリング
- [ ] 全コードのレビュー
  - コードスタイル統一（RuboCop実行）
  - コメントの追加（複雑なロジック）
  - 冗長なコードの削減
- [ ] パフォーマンスの確認
  - 実行時間計測
  - メモリ使用量確認

**検証**:
- RuboCopが全て通過する
- 実行時間が5分以内

**依存関係**: Task 3.3

---

### Task 5.4: 最終テストとデプロイ
- [ ] 全テストスイートの実行
  - ユニットテスト
  - 統合テスト
  - エンドツーエンドテスト
- [ ] 本番環境でのテスト実行（少量データ）
- [ ] GitHub Actionsのcronを有効化
- [ ] 初回自動実行の確認

**検証**:
- 全テストが通過する
- 本番環境で正常に動作する
- 自動実行が設定時刻に起動する

**依存関係**: Task 5.1, Task 5.3

---

## 並列化可能なタスク

以下のタスクは依存関係がなく、並列で作業可能:
- Task 1.2 と Task 1.3（両方ともTask 1.1に依存）
- Task 2.3 と Task 2.4（両方ともTask 2.2に依存）
- Task 5.1 と Task 5.2（Phase 5の一部）

## 見積もり
- Phase 1: 0.5日
- Phase 2: 2-3日
- Phase 3: 1-1.5日
- Phase 4: 0.5-1日
- Phase 5: 0.5-1日

**合計**: 5-7日
