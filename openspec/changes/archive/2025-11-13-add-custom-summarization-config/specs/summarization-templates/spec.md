# summarization-templates Spec Delta

## REMOVED Requirements

### Requirement: テンプレート選択機能
**Reason**: 事前定義テンプレートの仕組みを廃止し、`config/sources.yml`での完全カスタムプロンプト設定に統一するため。ユーザーは設定ファイルで直接`system_prompt`と`output_format`を記述できるようになり、柔軟性が向上します。

**Migration**: 既存のテンプレート使用者は、以下のようにYAML設定に移行してください：

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

ドキュメント（CLAUDE.md）に既存5テンプレート（default, concise, detailed, technical, bullet_points）に相当するYAML例を提供します。

---

### Requirement: 事前定義テンプレートの提供
**Reason**: カスタムプロンプト設定に統一するため、事前定義テンプレートは不要になります。

**Migration**: 必要に応じて、ドキュメントから適切なYAML例をコピーして使用してください。

---

### Requirement: 設定バリデーション
**Reason**: テンプレート名の検証は不要になります。代わりに、`content-summarization`specで定義されるカスタムプロンプトのバリデーションが適用されます。

**Migration**: 新しいバリデーションは`system_prompt`と`output_format`の妥当性を検証します（空文字列チェック、型チェック、最大長チェック）。

---

### Requirement: 後方互換性の維持
**Reason**: この変更は意図的なBREAKING CHANGEであり、既存のテンプレート方式は廃止されます。

**Migration**: すべてのユーザーは`template`設定を`system_prompt`と`output_format`の設定に更新する必要があります。

---

### Requirement: ログと可観測性
**Reason**: テンプレート名のログは不要になります。代わりに、カスタムプロンプトの使用状況がログに記録されます（`content-summarization`specで定義）。

**Migration**: ログメッセージは「Using summarization template: X」から「Using custom/default summarization prompts」に変更されます。

---

### Requirement: パフォーマンスへの影響最小化
**Reason**: カスタムプロンプト方式でも同様のパフォーマンス特性が維持されるため、この要件は`content-summarization`に統合されます。

**Migration**: プロンプトの読み込みは引き続き初期化時に1回のみ実行されます。実行時オーバーヘッドは変わりません。
