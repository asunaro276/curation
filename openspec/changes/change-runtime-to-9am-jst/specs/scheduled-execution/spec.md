# Capability: スケジュール実行 (scheduled-execution)

## 説明
実行時間を日本時間の午前9時に変更するための仕様差分

## MODIFIED Requirements

### Requirement: Cron-based定期実行
GitHub Actionsのcronトリガーを使用して、設定されたスケジュールで実行されなければならない (MUST)。

#### Scenario: 日次実行の設定
**Given** GitHub Actionsワークフローが設定されている
**When** cron式 `0 0 * * *` (UTC 0:00, JST 9:00) が設定される
**Then** 毎日日本時間午前9時にワークフローが自動実行される
**And** 全プロセス（収集→要約→投稿）が順次実行される
**And** ユーザーは朝の業務開始時に最新の技術ニュースを受け取ることができる

#### Scenario: 手動トリガーのサポート
**Given** ワークフローに `workflow_dispatch` が設定されている
**When** GitHubのActionsタブから手動実行が選択される
**Then** 即座にワークフローが起動する
**And** 通常のcron実行と同じプロセスが実行される
