# Proposal: LINE Messaging API統合

## 概要
既存のSlack通知に加えて、LINE Messaging APIを使用したメッセージ配信機能を追加する。これにより、技術ニュースの要約をLINEグループやトークルームにも配信できるようになる。

## 動機
- Slackを使用していないチームやコミュニティへの配信ニーズ
- 日本市場でのLINEの高い普及率を活用
- より広いユーザー層への技術情報配信を可能にする
- 複数の通知チャネルをサポートすることで柔軟性を向上

## 目標
1. LINE Messaging APIと統合し、メッセージを配信できるようにする
2. 既存のNotifierアーキテクチャを拡張し、複数の通知先をサポート
3. LINE特有のメッセージフォーマット（Flex Message等）に対応
4. Slack通知との並行配信を可能にする
5. 設定ファイルで通知先を柔軟に選択できるようにする

## 範囲内
- LINE Messaging APIクライアントの実装
- LINEメッセージフォーマッター（Flex Message対応）
- 複数通知先をサポートするNotifierアーキテクチャの拡張
- LINE Webhook URL/アクセストークンの設定管理
- LINEへの投稿機能とエラーハンドリング
- 既存のバッチ投稿機能とレート制限対応の適用
- 単体テストとインテグレーションテスト

## 範囲外
- LINE Botの双方向会話機能（メッセージ受信・応答）
- LINE Login機能やユーザー認証
- LINEスタンプや画像の送信
- 複数のLINEグループへの同時配信管理
- LINE特有の高度なUI機能（リッチメニュー等）
- Webベースの設定管理UI

## 影響を受けるコンポーネント
- **修正**: `TechNews::Notifier` - 抽象化と複数通知先対応
- **新規**: `TechNews::Notifiers::LineNotifier` - LINE Messaging API実装
- **修正**: `TechNews::Notifiers::SlackNotifier` - 既存Notifierから分離
- **新規**: `TechNews::Notifiers::Factory` - Notifierインスタンス生成
- **修正**: `TechNews::Orchestrator` - 複数notifierの呼び出し対応
- **修正**: `TechNews::Config` - LINE設定項目の追加
- **修正**: `.env.example` - LINE環境変数の追加
- **新規**: 各Notifierの単体テスト・インテグレーションテスト

## 依存関係
- LINE Messaging API - 必須（メッセージ配信）
- LINE Channel Access Token - 必須（API認証）
- 既存の依存: `faraday` gem（HTTP通信）
- 既存の依存: `json` gem（メッセージシリアライズ）

## リスクと緩和策
| リスク | 影響 | 緩和策 |
|--------|------|--------|
| LINE APIのレート制限 | 中 | バッチ送信の間隔調整、設定可能な待機時間 |
| Flex Messageフォーマットの複雑性 | 低 | シンプルなメッセージフォーマットから開始、段階的に拡張 |
| 既存Slack機能への影響 | 高 | 既存テストを維持、後方互換性を保つ設計 |
| 複数チャネル配信時のエラーハンドリング | 中 | 個別エラーを分離、一方の失敗が他方に影響しない設計 |
| LINE APIの認証情報管理 | 中 | 環境変数での管理、バリデーション強化 |

## 代替案
1. **Slackのみを継続使用**: シンプルだが、LINE利用者への配信ができない
2. **LINE Notifyを使用**: 簡単だが、Messaging APIより機能が限定的
3. **Zapier等のサードパーティサービス**: 追加コストと依存性が発生

## 成功基準
- [ ] LINE Messaging APIを使用してメッセージを送信できる
- [ ] Slack通知と並行してLINE通知が動作する
- [ ] どちらか一方の通知が失敗しても、もう一方は継続する
- [ ] 設定ファイルで通知先（Slack/LINE/両方）を選択できる
- [ ] LINEメッセージが読みやすくフォーマットされている（Flex Message使用）
- [ ] 既存のSlack通知機能が影響を受けない（後方互換性）
- [ ] 全てのテストが通過する
- [ ] エラー時のログが適切に記録される

## タイムライン
- フェーズ1: アーキテクチャ設計とNotifier抽象化 (1日)
- フェーズ2: LINE Notifier実装とメッセージフォーマッター (2日)
- フェーズ3: Orchestratorの複数通知先対応 (1日)
- フェーズ4: テスト実装とドキュメント更新 (1日)

合計見積もり: 5日

## 関連Capability
- `line-notification`: LINE Messaging APIを使用したメッセージ配信
- `multi-channel-notification`: 複数の通知チャネル（Slack + LINE）への配信管理
