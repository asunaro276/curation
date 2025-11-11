# Capability: 要約テンプレートカスタマイズ (summarization-templates)

## Purpose
記事要約時のプロンプトと出力形式を、事前定義されたテンプレートから選択できるようにする機能。ユースケースに応じて異なる要約スタイル（簡潔版、詳細版、技術特化版など）を使い分けることができます。

## Related To
- **Extends**: `content-summarization` - 既存の要約機能を拡張

---

## ADDED Requirements

### Requirement: テンプレート選択機能
設定ファイルでテンプレートを指定し、要約スタイルを切り替えられなければならない (MUST)。

#### Scenario: デフォルトテンプレートの使用
**Given** `config/sources.yml` に `summarization.template` が指定されていない
**When** 要約処理が実行される
**Then** 'default' テンプレートが自動的に選択される
**And** 既存の動作（2-3文の要約 + 最大3点の箇条書き）が維持される

#### Scenario: 簡潔テンプレートの選択
**Given** `config/sources.yml` に以下の設定がある:
```yaml
summarization:
  template: concise
```
**When** 記事が要約される
**Then** 'concise' テンプレートが適用される
**And** 1-2文の超簡潔な要約のみが生成される
**And** 箇条書きは含まれない

#### Scenario: 詳細テンプレートの選択
**Given** `config/sources.yml` に `template: detailed` が設定されている
**When** 記事が要約される
**Then** 4-5文の詳細な要約が生成される
**And** 約5点の詳細な箇条書きが含まれる

#### Scenario: 技術特化テンプレートの選択
**Given** `config/sources.yml` に `template: technical` が設定されている
**When** 技術記事が要約される
**Then** 技術的詳細（アーキテクチャ、使用技術、パフォーマンス指標など）に焦点を当てた要約が生成される
**And** 技術スタックや実装の詳細が箇条書きで含まれる

#### Scenario: 箇条書き専用テンプレートの選択
**Given** `config/sources.yml` に `template: bullet_points` が設定されている
**When** 記事が要約される
**Then** 文章形式の要約は生成されない
**And** 5-7点の箇条書きのみで構成される

---

### Requirement: 事前定義テンプレートの提供
一般的なユースケースをカバーする複数のテンプレートが利用可能でなければならない (MUST)。

#### Scenario: 利用可能なテンプレート一覧の確認
**Given** システムが起動している
**When** `SummarizerTemplates` モジュールに問い合わせる
**Then** 以下のテンプレートが利用可能:
- default: 標準的な要約（2-3文 + 箇条書き3点）
- concise: 超簡潔版（1-2文のみ）
- detailed: 詳細版（4-5文 + 箇条書き5点）
- technical: 技術特化版（技術詳細重視）
- bullet_points: 箇条書きのみ（5-7点）

#### Scenario: テンプレート定義の構造検証
**Given** 任意のテンプレート名（例: 'default'）
**When** テンプレート定義を取得する
**Then** 以下の要素が含まれている:
- `name`: テンプレート名（文字列）
- `system_prompt`: システムプロンプト（要約者の役割説明）
- `output_format`: 出力形式の指示（文字列）

#### Scenario: テンプレートのプロンプト生成
**Given** テンプレート 'concise' が選択されている
**And** 記事データ（title, url, source, content）が与えられている
**When** プロンプトを生成する
**Then** テンプレートの `system_prompt` と `output_format` が統合される
**And** 記事データがプロンプトに埋め込まれる
**And** 生成されたプロンプトは文字列として返される

---

### Requirement: 設定バリデーション
無効なテンプレート名が指定された場合、適切にエラー処理されなければならない (MUST)。

#### Scenario: 存在しないテンプレート名の検出
**Given** `config/sources.yml` に `template: invalid_template` が設定されている
**When** Configが初期化される
**Then** `ConfigurationError` 例外が発生する
**And** エラーメッセージに「無効なテンプレート名: invalid_template」が含まれる
**And** 利用可能なテンプレート一覧がエラーメッセージに含まれる

#### Scenario: テンプレート名の大文字小文字の扱い
**Given** `config/sources.yml` に `template: DEFAULT` (大文字) が設定されている
**When** テンプレートを取得する
**Then** 'default' テンプレートが正しく適用される
**And** 大文字小文字は区別されない（case-insensitive）

---

### Requirement: 後方互換性の維持
既存の設定ファイルやコードが引き続き動作しなければならない (MUST)。

#### Scenario: 既存の設定ファイルでの動作
**Given** `config/sources.yml` に `summarization` セクションが存在しない（旧形式）
**When** システムが起動する
**Then** エラーが発生しない
**And** 自動的に 'default' テンプレートが使用される
**And** 既存の要約動作が維持される

#### Scenario: 既存のテストスイートの互換性
**Given** テンプレート機能実装前のテストコード
**When** `bundle exec rspec` を実行する
**Then** すべての既存テストがパスする
**And** 新機能によって既存テストが破壊されていない

---

### Requirement: ログと可観測性
使用中のテンプレートは情報ログに記録されなければならない (MUST)。

#### Scenario: テンプレート選択のログ記録
**Given** `template: detailed` が設定されている
**When** Summarizerが初期化される
**Then** ログに「Using summarization template: detailed」が記録される
**And** ログレベルは INFO

#### Scenario: ドライラン実行での設定表示
**Given** `template: technical` が設定されている
**When** `./bin/run --dry-run` を実行する
**Then** 標準出力に使用中のテンプレート名が表示される
**And** テンプレートの説明も表示される

---

### Requirement: パフォーマンスへの影響最小化
テンプレート機能による実行時オーバーヘッドは無視できる程度でなければならない (MUST)。テンプレート選択ロジックは初期化時に1回のみ実行されなければならない (MUST)。

#### Scenario: テンプレート適用のオーバーヘッド測定
**Given** 100件の記事を要約する
**When** テンプレート機能を使用した場合と使用しない場合で実行時間を比較する
**Then** 実行時間の差は全体の5%未満である
**And** テンプレート選択ロジックは初期化時に1回のみ実行される

---

## MODIFIED Requirements

### (既存) Requirement: 要約品質の一貫性
要約は一貫したフォーマットと品質で生成されなければならない (MUST)。

#### (変更) Scenario: テンプレート別のフォーマット一貫性
**Given** 特定のテンプレート（例: 'bullet_points'）が選択されている
**When** 複数の記事が要約される
**Then** すべての要約がそのテンプレートの形式に従う
**And** テンプレート間で形式の混在が発生しない

**変更内容**: 既存のシナリオを拡張し、テンプレートごとに一貫性が保たれることを明示。

---

## Implementation Notes

### テンプレート定義の配置
- テンプレート定義は `lib/tech_news/summarizer_templates.rb` に集約
- モジュール形式で実装し、グローバルな名前空間汚染を避ける

### 設定の読み込み
- `TechNews::Config` クラスに `summarization_template` アクセサを追加
- デフォルト値は 'default'
- `sources.yml` の `summarization.template` から読み込み

### テンプレートの適用
- `TechNews::Summarizer#build_prompt` メソッドでテンプレートを使用
- テンプレートは初期化時に1回だけ読み込む（キャッシュ）
- 記事データ（title, url, source, content）をテンプレートに補間

### エラーハンドリング
- 無効なテンプレート名: `ConfigurationError` を発生
- テンプレート定義の不整合: システム起動時に検証

---

## Testing Strategy

### ユニットテスト
- `SummarizerTemplates` モジュールの各テンプレート定義をテスト
- `Config` のテンプレート読み込みとバリデーションをテスト
- `Summarizer` のプロンプト生成ロジックをテスト

### 統合テスト
- 各テンプレートでend-to-endの要約生成をテスト
- 外部API（Claude API）はWebMockでモック化
- 実際の記事データを使用してテンプレートの動作を検証

### 回帰テスト
- 既存のテストスイートが引き続きパスすることを確認
- デフォルト動作が変更されていないことを検証

---

## Documentation Requirements

以下のドキュメントを更新する必要があります：

1. **CLAUDE.md**:
   - 新しい設定オプションの説明
   - 利用可能なテンプレート一覧と各テンプレートの特徴

2. **config/sources.yml**:
   - `summarization` セクションのコメントでテンプレート一覧を記載

3. **README.md** (存在する場合):
   - クイックスタートガイドにテンプレート選択の例を追加

---

## Related Capabilities
- **content-summarization**: この変更の基盤となる既存の要約機能
- **news-collection**: 要約対象の記事データを提供
- **slack-notification**: 生成された要約を受け取り投稿（今回は変更なし）
