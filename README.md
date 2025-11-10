# Tech News Curation System

技術ニュースを自動収集し、Claude APIで要約してSlackに投稿するシステム

## 概要

このシステムは以下の機能を提供します：

- 複数の技術ニュースソース（RSS、GitHub Trending等）から記事を自動収集
- Claude API (Anthropic)を使用して記事を日本語で要約
- 要約をSlackチャンネルに自動投稿（Block Kit形式）
- GitHub Actionsによる定期実行（cron）
- エラーハンドリングとリトライ機能
- 機密情報の自動マスキング

## 必須要件

- Ruby 3.0以上
- Bundler
- Anthropic API Key (Claude API)
- Slack Incoming Webhook URL
- GitHub Actions (自動実行用)

## セットアップ

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd curation
```

### 2. 依存関係のインストール

```bash
bundle install
```

### 3. 環境変数の設定（ローカル開発用）

`.env.example`をコピーして`.env`を作成し、必要な値を設定してください：

```bash
cp .env.example .env
```

`.env`ファイルを編集：

```env
# Claude API (Anthropic)
ANTHROPIC_API_KEY=sk-ant-api03-your-actual-api-key-here

# Slack Webhook URL
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Optional settings
LOG_LEVEL=INFO
CLAUDE_MODEL=claude-3-5-sonnet-20241022
MAX_ARTICLES_PER_SOURCE=5
```

#### APIキーの取得方法

**Anthropic API Key:**
1. [Anthropic Console](https://console.anthropic.com/)にアクセス
2. API Keysページで新しいキーを作成
3. キーをコピーして`ANTHROPIC_API_KEY`に設定

**Slack Webhook URL:**
1. [Slack API](https://api.slack.com/apps)にアクセス
2. "Create New App" → "From scratch"を選択
3. "Incoming Webhooks"機能を有効化
4. "Add New Webhook to Workspace"で投稿先チャンネルを選択
5. 生成されたWebhook URLをコピーして`SLACK_WEBHOOK_URL`に設定

### 4. ニュースソースの設定

`config/sources.example.yml`をコピーして`config/sources.yml`を作成：

```bash
cp config/sources.example.yml config/sources.yml
```

`config/sources.yml`を編集して、収集したいニュースソースを設定：

```yaml
sources:
  - type: rss
    name: "Hacker News"
    url: "https://news.ycombinator.com/rss"
    enabled: true

  - type: github_trending
    name: "GitHub Trending Ruby"
    language: "ruby"
    enabled: true
```

## 使い方

### ローカルでの実行

#### 基本実行

```bash
./bin/run
```

#### ドライラン（API呼び出しをスキップ）

```bash
./bin/run --dry-run
```

#### 詳細ログ付き実行

```bash
./bin/run --verbose
```

#### カスタム設定ファイルを使用

```bash
./bin/run --config path/to/custom/sources.yml
```

### GitHub Actionsでの自動実行

#### 1. GitHub Secretsの設定

リポジトリの Settings → Secrets and variables → Actions で以下のSecretsを追加：

| Secret名 | 説明 | 例 |
|---------|------|-----|
| `ANTHROPIC_API_KEY` | Claude APIキー | `sk-ant-api03-...` |
| `SLACK_WEBHOOK_URL` | Slack Webhook URL | `https://hooks.slack.com/services/...` |

#### 2. ワークフローの確認

`.github/workflows/run-curation.yml`がリポジトリにコミットされていることを確認してください。

#### 3. 実行スケジュール

デフォルトでは毎日午後11時（UTC）= 午前8時（JST）に自動実行されます。

スケジュールを変更する場合は、`.github/workflows/run-curation.yml`のcron設定を編集：

```yaml
schedule:
  - cron: '0 23 * * *'  # 毎日23:00 UTC
```

#### 4. 手動実行

GitHub ActionsのUIから手動でワークフローを実行することもできます：

1. リポジトリの "Actions" タブを開く
2. "Tech News Curation" ワークフローを選択
3. "Run workflow" ボタンをクリック

## テスト

### 全テストの実行

```bash
bundle exec rspec
```

### 特定のファイルのテスト

```bash
bundle exec rspec spec/tech_news/config_spec.rb
```

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│              GitHub Actions (Scheduler)                  │
│                   cron: 0 23 * * *                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   Orchestrator                           │
│                  (lib/orchestrator.rb)                  │
└───┬─────────────────┬─────────────────┬─────────────────┘
    │                 │                 │
    ▼                 ▼                 ▼
┌─────────┐     ┌─────────┐     ┌─────────────┐
│Collector│     │Summarizer│     │  Notifier   │
│ (収集)  │────▶│ (要約)   │────▶│ (通知)      │
└─────────┘     └─────────┘     └─────────────┘
```

### コンポーネント

- **Collector**: ニュースソース（RSS、GitHub Trending）からデータを収集
- **Summarizer**: Claude APIで記事を日本語で要約
- **Notifier**: Slackに投稿（Block Kit形式）
- **Orchestrator**: 全体のワークフローを制御

詳細なアーキテクチャ設計は`openspec/changes/setup-tech-news-system/design.md`を参照してください。

## トラブルシューティング

### エラー: "Configuration file not found"

**原因**: `config/sources.yml`が存在しない

**解決**:
```bash
cp config/sources.example.yml config/sources.yml
```

### エラー: "ANTHROPIC_API_KEY environment variable is required"

**原因**: 環境変数が設定されていない

**解決**:
- ローカル: `.env`ファイルを作成してAPIキーを設定
- GitHub Actions: リポジトリのSecretsに`ANTHROPIC_API_KEY`を追加

### エラー: "Invalid Slack webhook URL"

**原因**: Webhook URLのフォーマットが正しくない

**解決**:
- URLが`https://hooks.slack.com/services/`で始まっているか確認
- Slack APIコンソールで新しいWebhook URLを生成

### エラー: "API rate limit exceeded"

**原因**: Claude APIまたはSlack APIのレート制限に達した

**解決**:
- `config/sources.yml`の`max_articles_per_source`を減らす
- 実行頻度を下げる（cronスケジュールを調整）

### GitHub Actionsでワークフローが実行されない

**確認事項**:
1. `.github/workflows/run-curation.yml`がmainブランチにコミットされているか
2. GitHub Actionsがリポジトリで有効化されているか
3. Secretsが正しく設定されているか

### ログの確認方法

**ローカル**:
```bash
./bin/run --verbose  # DEBUG レベルのログを表示
```

**GitHub Actions**:
1. リポジトリの "Actions" タブを開く
2. 実行したワークフローをクリック
3. "Run tech news curation" ステップのログを確認

## コスト管理

### Anthropic API

- Claude 3.5 Sonnetの料金（2024年11月時点）:
  - Input: $3 per million tokens
  - Output: $15 per million tokens

- 1記事あたりの推定コスト: 約$0.01-0.02
- 1日5記事 × 30日 = 約$1.50-3.00/月

### コスト削減のヒント

1. `max_articles_per_source`を減らす（デフォルト: 5）
2. `max_content_tokens`を調整してトークン数を制限
3. ソースを厳選して有用なものだけを有効化
4. cron実行頻度を下げる（1日1回 → 週2-3回など）

## カスタマイズ

### 新しいニュースソースの追加

1. `config/sources.yml`に新しいソースを追加
2. RSSフィードの場合:
```yaml
- type: rss
  name: "Your Feed Name"
  url: "https://example.com/feed.xml"
  enabled: true
```

### 要約スタイルのカスタマイズ

`lib/tech_news/summarizer.rb`の`build_prompt`メソッドを編集してプロンプトをカスタマイズできます。

### Slackメッセージフォーマットのカスタマイズ

`lib/tech_news/notifier.rb`の`format_message`メソッドを編集してSlack Block Kitフォーマットをカスタマイズできます。

## 開発

### コードスタイル

```bash
bundle exec rubocop
```

### 新機能の追加

1. `lib/tech_news/`に新しいファイルを作成
2. `spec/tech_news/`に対応するテストを作成
3. テストを実行して確認

## ライセンス

MIT

## サポート

問題が発生した場合は、GitHubのIssuesで報告してください。
