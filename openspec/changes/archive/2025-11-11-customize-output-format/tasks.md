# Implementation Tasks: 要約出力形式のカスタマイズ

## タスク一覧

### 1. テンプレート定義モジュールの作成

**ファイル**: `lib/tech_news/summarizer_templates.rb`

**内容**:
- `SummarizerTemplates` モジュールを作成
- 5種類のテンプレート定義を実装（default, concise, detailed, technical, bullet_points）
- 各テンプレートは `name`, `system_prompt`, `output_format` を持つハッシュで定義
- テンプレート名からテンプレートを取得する `get_template(name)` メソッドを実装
- 存在しないテンプレート名の場合は例外を発生させる

**検証**:
- `bundle exec rspec spec/tech_news/summarizer_templates_spec.rb`
- 各テンプレートが正しい構造を持つことを確認
- 不正なテンプレート名で例外が発生することを確認

**依存**: なし（最初に実行可能）

---

### 2. Configクラスの拡張

**ファイル**: `lib/tech_news/config.rb`

**内容**:
- `sources.yml` から `summarization.template` 設定を読み込むメソッドを追加
- `summarization_template` アクセサを追加（デフォルト: 'default'）
- 設定値のバリデーション（有効なテンプレート名かチェック）

**検証**:
- `bundle exec rspec spec/tech_news/config_spec.rb`
- デフォルト値が正しく設定されることを確認
- `sources.yml` の設定値が正しく読み込まれることを確認
- 無効なテンプレート名でエラーが発生することを確認

**依存**: タスク1（テンプレート定義が必要）

---

### 3. Summarizerクラスの修正

**ファイル**: `lib/tech_news/summarizer.rb`

**内容**:
- `build_prompt` メソッドを修正してテンプレートを使用
- 初期化時に設定からテンプレート名を取得
- `SummarizerTemplates` モジュールからテンプレートを読み込み
- テンプレートに基づいてプロンプトを生成

**検証**:
- `bundle exec rspec spec/tech_news/summarizer_spec.rb`
- 各テンプレートで正しいプロンプトが生成されることを確認
- デフォルトテンプレートで既存の動作を維持することを確認
- WebMockで外部API呼び出しをモック化

**依存**: タスク1, 2（テンプレート定義とConfig拡張が必要）

---

### 4. 設定ファイルの更新

**ファイル**: `config/sources.yml`

**内容**:
- `summarization` セクションを追加
- `template: default` をデフォルト設定として追加
- コメントで利用可能なテンプレート一覧を記載

**検証**:
- YAML構文が正しいことを確認（`bundle exec ruby -e "require 'yaml'; YAML.load_file('config/sources.yml')"）
- 既存のテストがすべてパスすることを確認

**依存**: なし（並行実行可能）

---

### 5. 統合テストの追加

**ファイル**: `spec/integration/summarization_templates_spec.rb` (新規作成)

**内容**:
- 各テンプレートでend-to-endの要約生成をテスト
- Orchestrator経由で実際の動作を検証
- 外部APIはモック化

**検証**:
- `bundle exec rspec spec/integration/summarization_templates_spec.rb`
- すべてのテンプレートで要約が正常に生成されることを確認

**依存**: タスク1, 2, 3（すべての実装が完了している必要がある）

---

### 6. ドライラン機能の更新

**ファイル**: `bin/run`, `lib/tech_news/orchestrator.rb`

**内容**:
- `--dry-run` 実行時にテンプレート設定を表示
- ログ出力に使用中のテンプレート名を含める

**検証**:
- `./bin/run --dry-run` を実行
- ログにテンプレート名が表示されることを確認

**依存**: タスク3（Summarizer修正が必要）

---

### 7. ドキュメント更新

**ファイル**: `CLAUDE.md`, `README.md`（存在する場合）

**内容**:
- 新しい設定オプションの説明を追加
- 利用可能なテンプレート一覧と説明
- 使用例を追加

**検証**:
- ドキュメントの内容を目視確認
- 記載されている設定例が実際に動作することを確認

**依存**: タスク1-6（すべての実装が完了後に実施）

---

### 8. RuboCopチェックとコードスタイル修正

**検証コマンド**: `bundle exec rubocop`

**内容**:
- 新規・変更したファイルのコードスタイルをチェック
- 自動修正可能な問題は `rubocop -a` で修正
- 手動修正が必要な問題を解決

**依存**: タスク1-7（すべてのコード変更完了後）

---

## 実装順序

1. **Phase 1: 基礎実装**（並行実行可能）
   - タスク1: テンプレート定義
   - タスク4: 設定ファイル更新

2. **Phase 2: コア機能実装**（順次実行）
   - タスク2: Config拡張
   - タスク3: Summarizer修正

3. **Phase 3: 検証と仕上げ**（順次実行）
   - タスク5: 統合テスト
   - タスク6: ドライラン機能更新
   - タスク7: ドキュメント更新
   - タスク8: コードスタイルチェック

## 見積もり

- **所要時間**: 約2-3時間
- **変更ファイル数**: 約7-8ファイル
- **新規テスト**: 約20-30テストケース

## ロールバック手順

変更を元に戻す必要がある場合：

1. Git経由で変更をrevert: `git revert <commit-hash>`
2. `config/sources.yml` から `summarization` セクションを削除
3. テストを実行して問題がないことを確認: `bundle exec rspec`
