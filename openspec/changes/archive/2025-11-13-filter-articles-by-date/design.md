# 設計: 日付フィルタリング機能

## アーキテクチャの選択

### 1. フィルタリングロジックの配置
**決定**: `Base` collectorクラスに共通メソッド `filter_by_date` を追加

**理由**:
- RSSCollectorとGitHubTrendingCollectorの両方で使用するため、重複を避ける
- 既存の `limit_articles` メソッドと同様に、Baseクラスで共通的な記事フィルタリング機能を提供するパターンに従う
- 将来的に新しいコレクターが追加された場合も、同じロジックを再利用できる

**代替案**:
- モジュールとして切り出す: 小規模な機能のため、Baseクラスに含める方がシンプル
- 各コレクターで個別実装: コードの重複が発生し、メンテナンス性が低下

### 2. 日付範囲の計算
**決定**: システムの現在時刻（`Time.now`）を基準に、前日の0時〜24時を計算

```ruby
def calculate_yesterday_range
  now = Time.now
  yesterday_start = Time.new(now.year, now.month, now.day) - 86400  # 前日の0時0分0秒
  yesterday_end = yesterday_start + 86400 - 1  # 前日の23時59分59秒
  [yesterday_start, yesterday_end]
end
```

**理由**:
- シンプルで依存関係が少ない
- GitHub Actionsで環境変数 `TZ=Asia/Tokyo` を設定することで、日本時間での動作を保証
- Rubyの標準ライブラリのみで実装可能（追加のgemが不要）

**代替案**:
- `ActiveSupport` の `1.day.ago` を使用: 追加依存が発生するため避ける
- `tzinfo` gemで明示的にJST処理: より厳密だが、複雑性が増す

### 3. フィルタリングのタイミング
**決定**: `parse` メソッドの後、`limit_articles` メソッドの前に実行

```
extract_articles → filter_by_date → limit_articles
```

**理由**:
- まず全記事を抽出し、次に日付でフィルタリング、最後に数量制限を適用する順序が論理的
- `limit_articles` は既に `max_articles_per_source` の制限を適用しているため、日付フィルタリング後の記事に対して適用するのが適切
- 各ステップが独立しており、テストが書きやすい

### 4. 公開日時がない記事の扱い
**決定**: フィルタリング時に除外し、警告ログを記録

```ruby
def filter_by_date(articles)
  start_time, end_time = calculate_yesterday_range

  articles.select do |article|
    if article.published_at.nil?
      logger.warn("#{name}: Skipping article without published_at - #{article.title}")
      next false
    end

    article.published_at >= start_time && article.published_at <= end_time
  end
end
```

**理由**:
- ユーザーの要望「公開日時がない記事は除外する」に従う
- 警告ログを出力することで、デバッグや監視が容易
- 明確な基準で一貫性のある動作

### 5. GitHub Actionsでのタイムゾーン設定
**決定**: ワークフローファイルに `TZ=Asia/Tokyo` 環境変数を追加

```yaml
env:
  TZ: Asia/Tokyo
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

**理由**:
- システムレベルでタイムゾーンを設定することで、コード側でタイムゾーン処理を行う必要がない
- GitHub ActionsのデフォルトはUTCのため、明示的にJSTを設定する必要がある
- 環境変数による設定は、インフラ設定の標準的なアプローチ

## データフロー

```
Collector#collect
  ↓
Collector#fetch (各コレクター実装)
  ↓
Collector#parse (各コレクター実装)
  ↓
Base#filter_by_date ← 【新規追加】
  ↓
Base#limit_articles
  ↓
記事配列を返す
```

## テスト戦略

### 1. ユニットテスト（Base#filter_by_date）
- 前日の記事が含まれることを確認
- 前日より古い記事が除外されることを確認
- 前日より新しい記事が除外されることを確認
- published_atがnilの記事が除外されることを確認
- 境界値テスト（前日の0時0分0秒、23時59分59秒）

### 2. インテグレーションテスト
- RSSCollectorで日付フィルタリングが動作することを確認
- GitHubTrendingCollectorで日付フィルタリングが動作することを確認

### 3. 時刻固定の方法
Timecop gemまたはRubyの標準的なモックを使用して、テスト時の現在時刻を固定

```ruby
# Timecopを使用する場合
Timecop.freeze(Time.new(2025, 1, 15, 10, 0, 0)) do
  # テストコード
end
```

## パフォーマンスへの影響
- フィルタリング処理は `O(n)` で記事数に比例
- 現在の記事数（数件〜数十件）では無視できるレベル
- メモリ使用量への影響も軽微

## セキュリティ考慮事項
- タイムゾーン設定は環境変数経由で行い、コードには含めない
- 日付計算のロジックは標準的なため、セキュリティリスクは低い

## 後方互換性
- 既存のAPIや設定ファイルの変更は不要
- フィルタリングは透過的に追加されるため、既存の動作に影響しない（ただし、結果として収集される記事数は減少する可能性がある）
