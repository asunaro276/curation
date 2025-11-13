# Change: カスタム要約プロンプト設定機能の追加

## Why
現在、要約スタイルのカスタマイズは5つの事前定義テンプレート（default, concise, detailed, technical, bullet_points）からの選択に限定されています。ユーザーがより柔軟に要約の出力形式をカスタマイズできるようにするため、`config/sources.yml`で直接`system_prompt`と`output_format`を記述できる機能が必要です。これにより、ユーザーは自分のニーズに合わせた完全にカスタムな要約プロンプトを作成できるようになります。

## What Changes
- **BREAKING**: `lib/tech_news/summarizer_templates.rb`を削除し、事前定義テンプレートの仕組みを廃止
- `config/sources.yml`の`summarization`セクションを拡張し、`system_prompt`と`output_format`を直接記述可能にする
- `lib/tech_news/summarizer.rb`を修正し、YAML設定から直接プロンプトを読み込むように変更
- `lib/tech_news/config.rb`を修正し、新しい設定構造をバリデーション
- 既存のテストを新しい設定方式に合わせて更新
- サンプル設定とドキュメントを更新

## Impact
- **Affected specs**:
  - `content-summarization`: 要約プロンプトの構築ロジック変更
  - `summarization-templates`: このspecは削除される（事前定義テンプレート廃止のため）
- **Affected code**:
  - `lib/tech_news/summarizer_templates.rb`: 削除
  - `lib/tech_news/summarizer.rb`: プロンプト読み込みロジック変更
  - `lib/tech_news/config.rb`: 設定スキーマ変更とバリデーション追加
  - `config/sources.yml`: 設定フォーマット変更
  - `config/sources.example.yml`: サンプル設定更新
  - `spec/tech_news/summarizer_spec.rb`: テスト更新
  - `spec/tech_news/config_spec.rb`: バリデーションテスト追加
  - `CLAUDE.md`: ドキュメント更新
- **Breaking change**: 既存の`template`設定（例: `template: bullet_points`）は動作しなくなる
