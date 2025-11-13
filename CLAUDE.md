# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

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
│   │   └── 前日の記事のみを日付でフィルタリング
│   └── GitHubTrendingCollector - GitHub Trendingから収集
│       └── 前日の記事として扱う
│
├── Summarizer (lib/tech_news/summarizer.rb)
│   └── Claude APIで記事を日本語要約
│
└── Notifier (lib/tech_news/notifier.rb)
    └── Slackに投稿（Block Kit形式）
```

### 日付フィルタリング機能
- **前日の記事のみを収集**: システムは前日（0時0分0秒〜23時59分59秒）に公開された記事のみを収集します
- **タイムゾーン**: GitHub Actionsの実行環境では`TZ=Asia/Tokyo`を設定し、日本時間（JST）で動作します
- **公開日時がない記事**: フィルタリング時に除外され、警告ログが記録されます
- **GitHub Trending**: 公開日時が取得できないため、前日の正午として扱われます

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
- `config/sources.yml`のカスタムプロンプト（`system_prompt`と`output_format`）を使用
- レート制限とリトライ機能を実装

#### Notifier (`lib/tech_news/notifier.rb`)
- Slack Webhook経由でメッセージ投稿
- Block Kit形式でリッチなメッセージを構築
- **統合メッセージモード（デフォルト）**: 複数記事を1つのメッセージにまとめて送信
  - API呼び出し回数を大幅削減（10記事で1/10に）
  - メッセージサイズ制限（35,000バイト）の自動検証
  - 空の要約を自動的にフィルタリング
  - 記事間に区切り線を挿入して視認性を維持
- **個別メッセージモード**: `notify_batch(summaries, consolidated: false)` で従来の個別投稿も可能
- **メッセージフォーマットのカスタマイズ**:
  - 統合メッセージ: `#format_consolidated_message`メソッドを編集
  - 個別メッセージ: `#format_message`メソッドを編集

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
- `TZ`: タイムゾーン設定（GitHub Actionsでは`Asia/Tokyo`を推奨）日付フィルタリングに影響

### カスタム要約プロンプト設定

`config/sources.yml` の `summarization` セクションで、要約プロンプトを完全にカスタマイズできます。

#### 基本設定

```yaml
summarization:
  # システムプロンプト：要約者の役割を定義
  system_prompt: |
    あなたは技術ニュースのキュレーターです。
    以下の記事を日本語で要約してください。

  # 出力フォーマット：要約の形式を指定
  output_format: |
    以下の形式で出力してください:
    - 2-3文の簡潔な要約
    - 重要なポイント（箇条書き、最大3点）
```

#### カスタマイズのベストプラクティス

- **system_prompt**: 要約者の役割やトーン（例: 技術特化、初心者向けなど）を定義
- **output_format**: 具体的な出力形式を指示（箇条書き、文数、構造など）
- **プロンプトの長さ**: 各プロンプトは2000文字以内に収める（自動検証あり）
- **明確な指示**: 曖昧な表現を避け、具体的な形式を指定

#### 旧テンプレートからの移行

以前のバージョンでは `template: bullet_points` のような事前定義テンプレートを使用していましたが、現在は設定ファイルで直接プロンプトを記述する方式に変更されました。

移行例（旧`bullet_points`テンプレート）：

**旧設定**:
```yaml
summarization:
  template: bullet_points
```

**新設定**:
```yaml
summarization:
  system_prompt: |
    あなたは技術ニュースのキュレーターです。
    以下の記事を箇条書き形式で日本語で要約してください。
  output_format: |
    以下の形式で出力してください:
    - 箇条書きのみ（5-7点）
    - 各項目は簡潔に1文で記述
```

その他の旧テンプレート（default, concise, detailed, technical）のYAML例は、`config/sources.example.yml` を参照してください。

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