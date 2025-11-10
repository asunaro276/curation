# Design: 技術ニュース自動収集・配信システム

## アーキテクチャ概要

### システム構成
```
┌─────────────────────────────────────────────────────────┐
│              GitHub Actions (Scheduler)                  │
│                   cron: 0 9 * * *                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   Main Orchestrator                      │
│                  (lib/orchestrator.rb)                  │
└───┬─────────────────┬─────────────────┬─────────────────┘
    │                 │                 │
    ▼                 ▼                 ▼
┌─────────┐     ┌─────────┐     ┌─────────────┐
│ Collector│     │Summarizer│     │  Notifier   │
│ (収集)  │────▶│ (要約)   │────▶│ (通知)      │
└─────────┘     └─────────┘     └─────────────┘
    │                 │                 │
    ▼                 ▼                 ▼
┌─────────┐     ┌─────────┐     ┌─────────────┐
│RSS/API  │     │Claude   │     │Slack        │
│Sources  │     │API      │     │Webhook      │
└─────────┘     └─────────┘     └─────────────┘
```

## コンポーネント設計

### 1. Collector (ニュース収集)
**責任**: 複数ソースから記事データを取得

**クラス構造**:
```ruby
module TechNews
  module Collectors
    class Base
      def fetch # 抽象メソッド
      def parse # 抽象メソッド
    end

    class RssCollector < Base
      # RSS/Atomフィード対応
    end

    class GithubTrendingCollector < Base
      # GitHub Trending API対応
    end

    class CollectorFactory
      # 設定に基づいてコレクターを生成
    end
  end
end
```

**データモデル**:
```ruby
Article = Struct.new(
  :title,        # String
  :url,          # String
  :published_at, # Time
  :description,  # String (optional)
  :source,       # String
  :metadata,     # Hash (拡張可能)
  keyword_init: true
)
```

**設計判断**:
- **Strategy Pattern**: 各ソースタイプごとに独立したコレクタークラス
- **Factory Pattern**: 設定ベースでコレクターを動的生成
- **利点**: 新しいソースの追加が容易、各ソースの障害が分離される

### 2. Summarizer (要約生成)
**責任**: Claude APIを使用して記事を要約

**クラス構造**:
```ruby
module TechNews
  class Summarizer
    def initialize(api_key:, model: 'claude-3-5-sonnet-20241022')

    def summarize(article)
      # 単一記事の要約
    end

    def summarize_batch(articles, batch_size: 5)
      # バッチ処理（レート制限対策）
    end

    private

    def build_prompt(article)
      # プロンプト構築
    end

    def truncate_content(text, max_tokens: 4000)
      # トークン制限対応
    end
  end
end
```

**プロンプト戦略**:
```
あなたは技術ニュースのキュレーターです。
以下の記事を日本語で要約してください。

タイトル: {title}
URL: {url}
内容: {description/content}

以下の形式で出力してください:
1. 2-3文の簡潔な要約
2. 重要なポイント（箇条書き、最大3点）
```

**設計判断**:
- **APIクライアント**: `anthropic-ruby` gem使用
- **エラーハンドリング**: Exponential backoff with jitter
- **コスト管理**: トークン数制限、要約対象の絞り込み
- **利点**: Claude APIの高品質な日本語要約、明確な責任分離

### 3. Notifier (Slack通知)
**責任**: Slackへのメッセージ投稿

**クラス構造**:
```ruby
module TechNews
  class Notifier
    def initialize(webhook_url:)

    def notify(summary)
      # 単一要約の投稿
    end

    def notify_batch(summaries, interval: 1)
      # バッチ投稿（レート制限対策）
    end

    private

    def format_message(summary)
      # Slackフォーマット構築
    end
  end
end
```

**メッセージフォーマット**:
```json
{
  "blocks": [
    {
      "type": "header",
      "text": {"type": "plain_text", "text": "記事タイトル"}
    },
    {
      "type": "section",
      "text": {"type": "mrkdwn", "text": "要約テキスト"}
    },
    {
      "type": "section",
      "fields": [
        {"type": "mrkdwn", "text": "• ポイント1"},
        {"type": "mrkdwn", "text": "• ポイント2"}
      ]
    },
    {
      "type": "actions",
      "elements": [
        {"type": "button", "text": "続きを読む", "url": "記事URL"}
      ]
    }
  ]
}
```

**設計判断**:
- **HTTPクライアント**: 標準ライブラリ `net/http` または `faraday` gem
- **リトライ戦略**: Exponential backoff、429レスポンス対応
- **利点**: Slackの豊富なフォーマット機能活用、エラー時の継続性

### 4. Orchestrator (オーケストレーター)
**責任**: 全体のワークフロー制御

**クラス構造**:
```ruby
module TechNews
  class Orchestrator
    def initialize(config)
      @collector = build_collector(config)
      @summarizer = Summarizer.new(api_key: config.anthropic_api_key)
      @notifier = Notifier.new(webhook_url: config.slack_webhook_url)
      @logger = Logger.new(STDOUT)
    end

    def run
      articles = collect_articles
      summaries = summarize_articles(articles)
      publish_summaries(summaries)
    rescue => e
      handle_error(e)
    end

    private

    def collect_articles
      # 収集ロジック
    end

    def summarize_articles(articles)
      # 要約ロジック
    end

    def publish_summaries(summaries)
      # 投稿ロジック
    end
  end
end
```

### 5. Configuration (設定管理)
**ファイル**: `config/sources.yml`
```yaml
sources:
  - type: rss
    name: "Hacker News"
    url: "https://news.ycombinator.com/rss"
    enabled: true

  - type: github_trending
    name: "GitHub Trending"
    language: "ruby"
    enabled: true

  - type: rss
    name: "Ruby Weekly"
    url: "https://rubyweekly.com/rss"
    enabled: true

limits:
  max_articles_per_source: 5
  max_content_tokens: 4000
  api_timeout: 30

slack:
  post_interval: 1  # seconds
```

## データフロー

1. **収集フェーズ**:
   - Orchestratorが各Collectorを呼び出し
   - 各Collectorが独立して記事を取得
   - エラーは記録されるが他のソースに影響しない
   - 結果をArticle構造体の配列として返す

2. **要約フェーズ**:
   - Summarizerが記事配列を受け取る
   - バッチ処理で順次Claude APIを呼び出し
   - レート制限を考慮した待機時間を挿入
   - 要約結果を構造化データとして返す

3. **投稿フェーズ**:
   - Notifierが要約データを受け取る
   - Slackフォーマットに変換
   - 1秒間隔でメッセージを投稿
   - 投稿結果をログに記録

## トレードオフと代替案

### 1. データ永続化
**現在の決定**: データベースなし、ステートレス実行
**代替案**: SQLite/PostgreSQLで記事履歴を保存
**トレードオフ**:
- 利点: シンプル、低コスト、状態管理不要
- 欠点: 重複記事の検出が困難、履歴分析不可
- 判断: MVP段階ではシンプルさを優先、将来的に追加検討

### 2. LLM選択
**現在の決定**: Claude API (Anthropic)
**代替案**: GPT-4 (OpenAI), Gemini (Google)
**トレードオフ**:
- 利点: 高品質な日本語対応、長文コンテキスト
- 欠点: OpenAIより少し高コスト
- 判断: 要約品質と日本語対応を優先

### 3. 実行環境
**現在の決定**: GitHub Actions
**代替案**: AWS Lambda, Google Cloud Functions, 独自サーバー
**トレードオフ**:
- 利点: 無料枠、設定簡単、CI/CD統合
- 欠点: 実行時間制限、cron頻度制限
- 判断: MVP段階では無料枠とシンプルさを優先

### 4. プログラミング言語
**現在の決定**: Ruby
**代替案**: Python, Node.js
**トレードオフ**:
- 利点: 簡潔な文法、豊富なgem、スクリプト適性
- 欠点: Pythonに比べMLライブラリが少ない（今回は不要）
- 判断: ユーザー要件に基づく選択

## セキュリティ考慮事項

1. **機密情報管理**:
   - APIキー、Webhook URLはGitHub Secretsで管理
   - ログ出力時にマスキング処理

2. **入力検証**:
   - 外部ソースからのデータをサニタイズ
   - URL検証（悪意あるリダイレクト対策）

3. **レート制限**:
   - 外部APIへの過度なリクエストを防止
   - 適切な待機時間とリトライ戦略

4. **エラー露出**:
   - 本番環境でスタックトレースを露出しない
   - エラーメッセージから機密情報を除外

## パフォーマンス考慮事項

1. **並列処理**:
   - 初期実装は順次処理（シンプルさ優先）
   - 将来的に非同期処理（Thread/Fiber）検討

2. **タイムアウト設定**:
   - HTTP接続: 10秒
   - API呼び出し: 30秒
   - 全体処理: 10分

3. **メモリ使用**:
   - ストリーミング処理（大量記事対応）
   - 不要なデータの早期解放

## 拡張性

### 短期的拡張
- 新しいニュースソースの追加
- 要約スタイルのカスタマイズ
- Slack以外の通知先（Discord, Email）

### 長期的拡張
- 記事履歴データベース
- 重複検出機能
- ユーザー設定可能なフィルタリング
- WebベースのダッシュボードUI
