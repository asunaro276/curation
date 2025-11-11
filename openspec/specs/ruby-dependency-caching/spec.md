# Capability: Ruby依存関係キャッシュ (ruby-dependency-caching)

## Purpose
GitHub ActionsにおけるRuby gem依存関係の明示的なキャッシュ管理を提供する。Gemfile.lockをキーとして、bundle installの結果をキャッシュし、実行時間を短縮する。

## Requirements

### Requirement: Gemfile.lockベースのキャッシュキー生成
キャッシュキーは、OS、Rubyバージョン、Gemfile.lockのハッシュ値を組み合わせて生成されなければならない (MUST)。

#### Scenario: Gemfile.lockが変更されていない場合
**Given** 前回実行時のGemfile.lockが存在する
**When** 新しいワークフロー実行が開始される
**And** Gemfile.lockの内容が前回と同一である
**Then** キャッシュキーが前回と一致する
**And** キャッシュがヒットする
**And** bundle installが高速化される

#### Scenario: Gemfile.lockが変更された場合
**Given** 前回実行時のGemfile.lockが存在する
**When** Gemfile.lockに依存関係の追加・更新・削除がある
**And** 新しいワークフロー実行が開始される
**Then** キャッシュキーが前回と異なる
**And** キャッシュがミスする
**And** bundle installが完全に実行される
**And** 新しいキャッシュが保存される

### Requirement: キャッシュの保存と復元
vendor/bundle ディレクトリがキャッシュとして保存・復元されなければならない (MUST)。

#### Scenario: キャッシュの復元
**Given** 前回実行時のキャッシュが存在する
**When** ワークフローが開始される
**And** キャッシュキーが一致する
**Then** vendor/bundle ディレクトリが復元される
**And** bundle installがキャッシュを利用する
**And** 実行時間が短縮される

#### Scenario: キャッシュの保存
**Given** bundle installが完了した
**When** ワークフローが正常に終了する
**Then** vendor/bundle ディレクトリがキャッシュとして保存される
**And** 次回実行時に再利用可能になる

### Requirement: キャッシュヒット/ミスの可視化
キャッシュのヒット/ミス状態が、ワークフローログで明確に確認できなければならない (MUST)。

#### Scenario: キャッシュヒット時のログ出力
**Given** キャッシュが存在する
**When** キャッシュの復元が成功する
**Then** ログに「Cache restored from key: <キャッシュキー>」が出力される
**And** 開発者がキャッシュヒットを確認できる

#### Scenario: キャッシュミス時のログ出力
**Given** キャッシュが存在しないか、キーが一致しない
**When** キャッシュの復元が試行される
**Then** ログに「Cache not found for input keys: <キャッシュキー>」が出力される
**And** 開発者がキャッシュミスを確認できる
**And** 新しいキャッシュが作成されることが明示される

### Requirement: Bundle設定との統合
bundle installのパス設定が、キャッシュディレクトリと一致しなければならない (MUST)。

#### Scenario: Bundle設定の適用
**Given** ワークフローでRubyがセットアップされる
**When** bundle configコマンドが実行される
**Then** bundle install先がvendor/bundleに設定される
**And** キャッシュディレクトリと一致する
**And** 依存関係が正しい場所にインストールされる

## 関連Capability
なし（新規機能）
