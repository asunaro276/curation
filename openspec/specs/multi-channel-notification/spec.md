# Capability: マルチチャネル通知管理

## Purpose
Slack、LINEなど複数の通知チャネルに対して柔軟に配信できる通知管理機能。各チャネルは独立して動作し、一方のエラーが他方に影響しない。

## Requirements

### Requirement: Notifier抽象化とファクトリパターン
システムは、既存のNotifierを抽象化し、複数の通知先実装をサポートしなければならない (MUST)。全ての通知先は共通の`notify`および`notify_batch`インターフェースを実装すべきである (SHALL)。ファクトリは設定から有効な通知先を動的に生成すべきである (SHALL)。

#### Scenario: Notifier基底クラスのインターフェース定義
**Given**: `TechNews::Notifiers::Base` クラスが定義されている
**When**: サブクラスが `notify(summary)` と `notify_batch(summaries)` メソッドを実装する
**Then**: 共通のインターフェースで複数の通知先を扱える
**And**: 各サブクラスは独自のメッセージフォーマットを持つ

#### Scenario: 設定からのNotifierインスタンス生成
**Given**: 設定で `enabled_notifiers: ["slack", "line"]` が指定されている
**When**: `Notifiers::Factory.create_all(config)` が呼び出される
**Then**: SlackNotifierとLineNotifierのインスタンスが生成される
**And**: 各Notifierが適切な設定で初期化される
**And**: 配列でNotifierインスタンスが返される

#### Scenario: 無効な通知先タイプの処理
**Given**: 設定で `enabled_notifiers: ["slack", "invalid"]` が指定されている
**When**: `Notifiers::Factory.create_all(config)` が呼び出される
**Then**: SlackNotifierのみが生成される
**And**: "invalid" 通知先に対する警告ログが出力される
**And**: 例外はスローされない

---

### Requirement: Orchestratorの複数Notifier対応
Orchestratorは複数のNotifierを管理し、各通知先に並行して通知を送信しなければならない (MUST)。一方の通知先の失敗は他の通知先の実行を妨げてはならない (MUST NOT)。全ての通知先が失敗した場合のみ例外をスローすべきである (SHALL)。

#### Scenario: 複数通知先への並行配信
**Given**: SlackとLINEの両方が有効化されている
**And**: 3件の記事要約がある
**When**: `orchestrator.run` が実行される
**Then**: 各記事要約がSlackに送信される
**And**: 各記事要約がLINEに送信される
**And**: 各通知先への送信結果が個別にログ記録される

#### Scenario: 一方の通知先が失敗しても他方は継続
**Given**: SlackとLINEの両方が有効化されている
**And**: Slack APIが一時的にダウンしている
**When**: `orchestrator.run` が実行される
**Then**: Slackへの送信が失敗する
**And**: エラーログに失敗が記録される
**And**: LINEへの送信は正常に完了する
**And**: Orchestratorの実行は継続する

#### Scenario: 全ての通知先が失敗
**Given**: SlackとLINEの両方が有効化されている
**And**: 両方のAPIが失敗する
**When**: `orchestrator.run` が実行される
**Then**: 両方の送信エラーがログに記録される
**And**: 実行結果に全ての失敗が反映される
**And**: `NotifierError` 例外がスローされる

---

### Requirement: 設定管理の拡張
システムは、複数通知先の有効化/無効化と個別設定を管理しなければならない (MUST)。`enabled_notifiers`設定により、どの通知先を使用するかを指定すべきである (SHALL)。デフォルトではSlackのみが有効であり、後方互換性を維持すべきである (SHALL)。

#### Scenario: 通知先の有効化設定
**Given**: 環境変数 `TECH_NEWS_ENABLED_NOTIFIERS="slack,line"` が設定されている
**When**: `Config.new` が呼び出される
**Then**: `config.enabled_notifiers` が `["slack", "line"]` を返す
**And**: 両方の通知先が有効と判定される

#### Scenario: 単一通知先のみ有効化
**Given**: 環境変数 `TECH_NEWS_ENABLED_NOTIFIERS="line"` が設定されている
**When**: `Config.new` が呼び出される
**Then**: `config.enabled_notifiers` が `["line"]` を返す
**And**: LINE通知のみが有効と判定される
**And**: Slack設定のバリデーションがスキップされる

#### Scenario: 通知先未指定時のデフォルト動作
**Given**: `TECH_NEWS_ENABLED_NOTIFIERS` が未設定
**When**: `Config.new` が呼び出される
**Then**: `config.enabled_notifiers` が `["slack"]` を返す
**And**: 後方互換性のためSlackがデフォルトで有効になる

---

### Requirement: 通知結果の集約レポート
システムは、複数通知先への配信結果を集約してレポートしなければならない (MUST)。各通知先別の成功数、失敗数、および送信時間をログに記録すべきである (SHALL)。

#### Scenario: 複数通知先の結果集約
**Given**: SlackとLINEへの配信が完了している
**And**: Slackは5件成功、LINEは4件成功・1件失敗
**When**: `report_results` が呼び出される
**Then**: ログに通知先ごとの送信結果が出力される
**And**: "Slack: 5 posted, 0 failed" が含まれる
**And**: "LINE: 4 posted, 1 failed" が含まれる
**And**: 合計の成功数と失敗数が表示される

#### Scenario: 通知先別のパフォーマンス記録
**Given**: 各通知先への送信が完了している
**When**: `report_results` が呼び出される
**Then**: 各通知先の送信時間がログに記録される
**And**: 最も遅い通知先が識別される

---

### Requirement: 既存Slack Notifierのリファクタリング
既存の`TechNews::Notifier`を`TechNews::Notifiers::SlackNotifier`に移動し、基底クラスを継承しなければならない (MUST)。全ての既存機能とテストは後方互換性を維持すべきである (SHALL)。

#### Scenario: Slack Notifierの後方互換性維持
**Given**: 既存のSlack通知コードがある
**When**: リファクタリング後の`SlackNotifier`が使用される
**Then**: 既存の全ての機能が動作する
**And**: メッセージフォーマットが変更されない
**And**: 全ての既存テストが通過する

#### Scenario: Base Notifierの継承
**Given**: `SlackNotifier` が `Notifiers::Base` を継承している
**When**: `notify` と `notify_batch` メソッドが呼び出される
**Then**: 基底クラスの共通ロジックが使用される
**And**: Slack固有のフォーマット処理が適用される

---

## Related Capabilities
- `line-notification`: LINE通知の実装詳細
- `slack-notification`: 既存Slack通知機能
