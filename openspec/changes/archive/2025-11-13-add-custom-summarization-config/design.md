# Design: カスタム要約プロンプト設定

## Context
現在の実装では、`SummarizerTemplates`モジュールに5つの事前定義テンプレートがハードコードされており、ユーザーは`config/sources.yml`でテンプレート名（例: `template: technical`）を指定して選択する仕組みです。この設計では、新しい要約スタイルを追加するためにはコードの変更が必要であり、柔軟性に欠けています。

ユーザーからのフィードバックにより、完全にカスタムなプロンプトを設定ファイルで直接指定できるようにする必要があることが明らかになりました。

## Goals / Non-Goals

### Goals
- `config/sources.yml`で`system_prompt`と`output_format`を完全にカスタマイズ可能にする
- 事前定義テンプレートへの依存を完全に排除し、設定ファイルベースの管理に統一する
- シンプルなYAML設定でプロンプトをカスタマイズできるようにする
- 設定の妥当性を検証し、明確なエラーメッセージを提供する

### Non-Goals
- 事前定義テンプレートの後方互換性を維持する（BREAKING CHANGEとして扱う）
- ソース別のテンプレート設定（将来的な拡張として残す）
- テンプレートの動的リロード機能

## Decisions

### Decision 1: 設定フォーマット
`config/sources.yml`の`summarization`セクションを以下の構造に変更します：

```yaml
summarization:
  system_prompt: |
    あなたは技術ニュースのキュレーターです。
    以下の記事を日本語で要約してください。
  output_format: |
    以下の形式で出力してください:
    - 2-3文の簡潔な要約
    - 重要なポイント（箇条書き、最大3点）
```

**理由**:
- YAMLの複数行文字列（`|`）を使用することで、プロンプトの可読性が向上
- `system_prompt`と`output_format`を分離することで、役割とフォーマット指示を明確に区別
- ユーザーが直感的に編集できるシンプルな構造

**Alternatives considered**:
- 単一の`prompt`フィールドにすべてを含める → 分離した方が役割が明確で保守しやすい
- JSON形式での設定 → YAMLの方がコメントや複数行文字列の扱いが容易

### Decision 2: デフォルト値の提供
`system_prompt`または`output_format`が設定されていない場合、`lib/tech_news/config.rb`でデフォルト値を提供します。

```ruby
DEFAULT_SYSTEM_PROMPT = 'あなたは技術ニュースのキュレーターです。以下の記事を日本語で要約してください。'
DEFAULT_OUTPUT_FORMAT = <<~FORMAT
  以下の形式で出力してください:
  - 2-3文の簡潔な要約
  - 重要なポイント（箇条書き、最大3点）
FORMAT
```

**理由**:
- 設定ファイルを最小限に保つことができる
- 既存の「default」テンプレートと同等の動作を維持
- ユーザーが部分的なカスタマイズのみを行う場合にも対応

**Alternatives considered**:
- デフォルト値なしで必須とする → ユーザーに不要な負担をかける
- 複数のプリセットを提供 → 事前定義テンプレートと同じ問題に戻ってしまう

### Decision 3: SummarizerTemplatesモジュールの削除
`lib/tech_news/summarizer_templates.rb`を完全に削除します。

**理由**:
- 設定ファイルベースのアプローチと二重管理になる
- コードの複雑性を減らし、保守性を向上
- ユーザーが必要なら、既存のテンプレートをYAML例として提供すれば十分

**Migration**:
ドキュメント（CLAUDE.md）に既存テンプレートのYAML例を記載し、ユーザーが移行しやすくします。

### Decision 4: バリデーション戦略
`lib/tech_news/config.rb`で以下をバリデーション：
- `system_prompt`と`output_format`は文字列であること
- 空文字列でないこと（空白のみもNG）
- 最大長制限（各2000文字以内）を設定（Claude APIの制限を考慮）

**理由**:
- 設定ミスを早期に検出し、実行時エラーを防ぐ
- 明確なエラーメッセージでユーザーの修正を支援

## Risks / Trade-offs

### Risk 1: 既存ユーザーへの影響（BREAKING CHANGE）
**Risk**: 既存の`template: bullet_points`などの設定が動作しなくなる
**Mitigation**:
- CLAUDE.mdに明確な移行ガイドを記載
- 既存テンプレートのYAML例を提供
- エラーメッセージで移行方法を案内

### Risk 2: プロンプトの品質管理
**Risk**: ユーザーが不適切なプロンプトを設定し、要約品質が低下する可能性
**Mitigation**:
- CLAUDE.mdにベストプラクティスとサンプルプロンプトを提供
- デフォルト値を適切に設定し、カスタマイズのベースラインを示す

### Risk 3: 設定ファイルの肥大化
**Risk**: 複雑なプロンプトを設定すると`sources.yml`が読みにくくなる
**Mitigation**:
- YAMLの複数行文字列（`|`）を使用し、可読性を確保
- 適切なインデントとコメントの推奨

## Migration Plan

### Phase 1: 実装（この変更で完了）
1. `lib/tech_news/config.rb`に新しい設定スキーマとバリデーションを追加
2. `lib/tech_news/summarizer.rb`を設定ファイル直接読み込みに変更
3. `lib/tech_news/summarizer_templates.rb`を削除
4. テストを新しい設定方式に更新
5. `config/sources.yml`と`config/sources.example.yml`を更新
6. CLAUDE.mdに移行ガイドとYAML例を追加

### Phase 2: ユーザー移行（手動）
ユーザーが既存の設定を以下のように変更：

**Before**:
```yaml
summarization:
  template: bullet_points
```

**After**:
```yaml
summarization:
  system_prompt: |
    あなたは技術ニュースのキュレーターです。
    以下の記事を箇条書き形式で日本語で要約してください。
  output_format: |
    以下の形式で出力してください:
    - 箇条書きのみ（5-7点）
    - 各項目は簡潔に1文で記述
```

### Rollback Plan
- 変更はすべて単一のPRで行われ、リバートで元に戻せる
- 既存のテンプレートコードは削除されるため、ロールバック時は旧コードをリストア

## Open Questions
なし（ユーザーからの明確な要望に基づいているため）
