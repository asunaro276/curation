# Implementation Tasks

## 1. 設定スキーマの変更と検証
- [x] 1.1 `lib/tech_news/config.rb`に`system_prompt`と`output_format`の読み込みロジックを追加
- [x] 1.2 デフォルト値の定数を定義（`DEFAULT_SYSTEM_PROMPT`, `DEFAULT_OUTPUT_FORMAT`）
- [x] 1.3 バリデーションロジックを実装（空文字列チェック、最大長チェック）
- [x] 1.4 `spec/tech_news/config_spec.rb`に設定バリデーションのテストを追加

## 2. Summarizerの変更
- [x] 2.1 `lib/tech_news/summarizer.rb`から`SummarizerTemplates`への依存を削除
- [x] 2.2 `config.system_prompt`と`config.output_format`を直接使用するように修正
- [x] 2.3 初期化ログを更新（テンプレート名→カスタムプロンプト使用を表示）
- [x] 2.4 `spec/tech_news/summarizer_spec.rb`を新しい設定方式に合わせて更新

## 3. テンプレートモジュールの削除
- [x] 3.1 `lib/tech_news/summarizer_templates.rb`を削除
- [x] 3.2 関連するテストファイル（該当する場合）を削除
- [x] 3.3 `require_relative 'summarizer_templates'`の参照を削除

## 4. 設定ファイルの更新
- [x] 4.1 `config/sources.yml`を新しいフォーマットに更新
- [x] 4.2 `config/sources.example.yml`にカスタムプロンプトのサンプルを追加
- [x] 4.3 既存の5つのテンプレートをYAML例としてコメントで提供

## 5. ドキュメント更新
- [x] 5.1 `CLAUDE.md`の「要約テンプレート設定」セクションを更新
- [x] 5.2 既存テンプレートからの移行ガイドを追加
- [x] 5.3 カスタムプロンプトのベストプラクティスを記載
- [x] 5.4 5つの旧テンプレートに相当するYAML例を記載

## 6. テストと検証
- [x] 6.1 全テストが通ることを確認（`bundle exec rspec`）
- [x] 6.2 RuboCopのチェックが通ることを確認（`bundle exec rubocop`）
- [x] 6.3 ドライラン実行で設定が正しく読み込まれることを確認（`./bin/run --dry-run`）
- [ ] 6.4 実際のAPI呼び出しでカスタムプロンプトが正しく動作することを確認

## 7. OpenSpec検証
- [x] 7.1 `openspec validate add-custom-summarization-config --strict`を実行
- [x] 7.2 すべての検証エラーを解消
