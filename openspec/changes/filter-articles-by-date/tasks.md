# 実装タスク

## 1. Baseコレクターに日付フィルタリング機能を追加
- [ ] 1.1 前日の日付範囲を計算する `calculate_yesterday_range` メソッドを実装
- [ ] 1.2 記事を日付でフィルタリングする `filter_by_date` メソッドを実装
- [ ] 1.3 published_atがnilの記事を除外し、警告ログを出力
- [ ] 1.4 日付フィルタリングのユニットテストを追加（時刻固定を使用）

## 2. RSSCollectorの更新
- [ ] 2.1 `parse` メソッドで `filter_by_date` を呼び出すように変更
- [ ] 2.2 フィルタリング後に `limit_articles` を呼び出す順序を確認
- [ ] 2.3 RSSCollectorのインテグレーションテストを更新

## 3. GitHubTrendingCollectorの更新（存在する場合）
- [ ] 3.1 GitHubTrendingCollectorが存在するか確認
- [ ] 3.2 存在する場合、RSSCollectorと同様に `filter_by_date` を適用
- [ ] 3.3 インテグレーションテストを更新

## 4. GitHub Actionsワークフローの更新
- [ ] 4.1 `.github/workflows/run-curation.yml` に環境変数 `TZ=Asia/Tokyo` を追加
- [ ] 4.2 ワークフローが日本時間で動作することを確認

## 5. テストの追加
- [ ] 5.1 前日の記事が含まれることを確認するテスト
- [ ] 5.2 前日より古い記事が除外されることを確認するテスト
- [ ] 5.3 前日より新しい記事が除外されることを確認するテスト
- [ ] 5.4 境界値テスト（前日の0時0分0秒、23時59分59秒）
- [ ] 5.5 published_atがnilの記事が除外されることを確認するテスト
- [ ] 5.6 全記事にpublished_atがない場合のテスト

## 6. ドキュメント更新
- [ ] 6.1 CLAUDE.mdを更新して日付フィルタリング機能を記載
- [ ] 6.2 必要に応じてREADME.mdを更新
- [ ] 6.3 環境変数TZの設定についてドキュメント化
