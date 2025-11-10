# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- OPENSPEC:START -->
# OpenSpec 説明書

これらの説明は、このプロジェクトで作業する AI アシスタント向けです。

以下のようなリクエストの場合は、必ず `@/openspec/AGENTS.md` を開いてください:
- 計画や提案に言及している（提案、仕様、変更、計画などの言葉）
- 新機能、破壊的変更、アーキテクチャの変更、大規模なパフォーマンス/セキュリティ作業を導入する
- 曖昧に聞こえ、コーディング前に権威ある仕様が必要な場合

`@/openspec/AGENTS.md` を使用して以下を学習してください:
- 変更提案の作成と適用方法
- 仕様のフォーマットと規約
- プロジェクト構造とガイドライン

'openspec update' が説明を更新できるように、この管理ブロックを保持してください。

<!-- OPENSPEC:END -->

---

## コミュニケーション

**重要**: ユーザーとのやり取りは必ず日本語で行ってください。コードのコメント、コミットメッセージ、ドキュメントも日本語で記述します。

---

## プロジェクト概要

技術ニュースを自動収集し、Claude APIで要約してSlackに投稿する自動キュレーションシステムです。

### 技術スタック
- Ruby 3.0以上
- Claude API (Anthropic) - 記事要約用
- Slack Webhook - 投稿配信用
- GitHub Actions - 定期実行基盤

### アーキテクチャ
システムは3つの主要コンポーネントで構成されています：

```
Orchestrator (lib/tech_news/orchestrator.rb)
    ↓
├── Collector (lib/tech_news/collectors/)
│   ├── RSSCollector - RSSフィードから記事収集
│   └── GitHubTrendingCollector - GitHub Trendingから収集
│
├── Summarizer (lib/tech_news/summarizer.rb)
│   └── Claude APIで記事を日本語要約
│
└── Notifier (lib/tech_news/notifier.rb)
    └── Slackに投稿（Block Kit形式）
```

---

## よく使うコマンド

### 開発とテスト

```bash
# 依存関係のインストール
bundle install

# テスト実行
bundle exec rspec                                    # 全テスト
bundle exec rspec spec/tech_news/config_spec.rb      # 特定ファイル
bundle exec rspec spec/tech_news/                    # ディレクトリ単位

# コードスタイルチェック
bundle exec rubocop                                  # 全ファイル
bundle exec rubocop lib/tech_news/notifier.rb        # 特定ファイル
bundle exec rubocop -a                               # 自動修正
```

### アプリケーション実行

```bash
# 基本実行
./bin/run

# ドライラン（API呼び出しなし、テスト用）
./bin/run --dry-run

# 詳細ログ付き実行（デバッグ用）
./bin/run --verbose

# カスタム設定ファイルを使用
./bin/run --config path/to/custom/sources.yml
```

### 設定ファイル

```bash
# 環境変数設定（ローカル開発用）
cp .env.example .env
# .envファイルを編集してAPIキーを設定

# ニュースソース設定
cp config/sources.example.yml config/sources.yml
# sources.ymlを編集して収集するソースを設定
```

---

## コードアーキテクチャの詳細

### 主要クラスと責務

#### Orchestrator (`lib/tech_news/orchestrator.rb`)
- 全体のワークフローを制御
- Collector → Summarizer → Notifier の順に実行
- エラーハンドリングと実行結果の集約

#### Collector Factory Pattern (`lib/tech_news/collectors/`)
- `factory.rb`: コレクターの生成を管理
- `base.rb`: 全コレクターの基底クラス
- `rss_collector.rb`: RSSフィードから記事収集
- `github_trending_collector.rb`: GitHub Trendingから収集
- **新しいソースを追加する場合**: Baseクラスを継承し、`#collect`メソッドを実装

#### Summarizer (`lib/tech_news/summarizer.rb`)
- Claude APIを使用して記事を日本語で要約
- プロンプトカスタマイズは`#build_prompt`メソッド
- レート制限とリトライ機能を実装

#### Notifier (`lib/tech_news/notifier.rb`)
- Slack Webhook経由でメッセージ投稿
- Block Kit形式でリッチなメッセージを構築
- バッチ投稿とレート制限回避機能
- **メッセージフォーマットのカスタマイズ**: `#format_message`メソッドを編集

#### Config (`lib/tech_news/config.rb`)
- `config/sources.yml`の読み込みと検証
- 環境変数の管理

#### Models (`lib/tech_news/models/article.rb`)
- 記事データを表現するシンプルなデータクラス
- 属性: title, url, description, published_at, source

---

## テスト戦略

### ベストプラクティス
- 外部API呼び出しは必ずWebMockでモック化
- ユニットテストはクラスの責務ごとに分離
- テストデータは`spec/fixtures/`に配置（必要に応じて）

### テストファイルの場所
- `spec/tech_news/` - 各クラスに対応するテストファイル
- `spec/spec_helper.rb` - RSpecの共通設定

---

## GitHub Actions

### ワークフロー (`.github/workflows/run-curation.yml`)
- 毎日23:00 UTC（8:00 JST）に自動実行
- 手動実行も可能（workflow_dispatch）
- 必要なシークレット:
  - `ANTHROPIC_API_KEY`: Claude APIキー
  - `SLACK_WEBHOOK_URL`: Slack Webhook URL

### 依存関係キャッシュ
- **キャッシュ方式**: actions/cache@v4 を使用した明示的なキャッシュ管理
- **キャッシュキー**: `${{ runner.os }}-ruby-3.2-gems-${{ hashFiles('**/Gemfile.lock') }}`
- **キャッシュパス**: `vendor/bundle`
- **動作**:
  - Gemfile.lockが変更されていない場合、キャッシュがヒットしてbundle installがスキップされる
  - Gemfile.lockが変更された場合、新規にbundle installが実行され、キャッシュが更新される
  - キャッシュヒット/ミス状態はワークフローログで確認可能
- **トラブルシューティング**:
  - キャッシュを強制的にクリアしたい場合は、GitHubのActionsタブからキャッシュを削除
  - ローカルで依存関係を変更した場合は、必ずGemfile.lockをコミット

---

## 環境変数

### 必須
- `ANTHROPIC_API_KEY`: Claude APIキー
- `SLACK_WEBHOOK_URL`: Slack Webhook URL

### オプション
- `LOG_LEVEL`: ログレベル（DEBUG, INFO, WARN, ERROR）デフォルト: INFO
- `CLAUDE_MODEL`: 使用するClaudeモデル（デフォルト: claude-3-5-sonnet-20241022）
- `MAX_ARTICLES_PER_SOURCE`: ソースあたりの最大記事数（デフォルト: 5）

---

## コーディング規約

### コードスタイル
- RuboCop準拠
- Ruby標準のスタイルガイドに従う
- frozen_string_literal: trueを各ファイルの先頭に記述

### 設計原則
- 単一責任の原則を守る
- 依存性注入パターンを使用（特にloggerやconfigの受け渡し）
- エラーは適切なカスタム例外クラスで処理（`lib/tech_news/errors.rb`）
- モジュール化とテスタビリティを重視

### コミット
- コミットメッセージは日本語可
- 意味のある単位でコミット
- OpenSpecを使用した変更は提案→実装→アーカイブのフローに従う

---

## トラブルシューティング

### よくある問題

**テストが失敗する**
- `bundle install`で依存関係が最新か確認
- WebMockが正しく外部APIをモック化しているか確認

**API関連のエラー**
- 環境変数が正しく設定されているか確認（`.env`ファイルまたはGitHub Secrets）
- APIキーの有効性を確認
- レート制限に達していないか確認

**設定ファイルエラー**
- `config/sources.yml`が存在するか確認
- YAMLの構文が正しいか確認

---

## プロジェクトの制約

### パフォーマンス
- GitHub Actions無料枠の実行時間制限（10分）
- Claude API利用量とコスト管理
- Slack投稿のレート制限遵守

### セキュリティ
- 環境変数での機密情報管理必須
- `.env`ファイルは`.gitignore`で除外されている
- API キーは絶対にコードに含めない