# content-summarization Spec Delta

## MODIFIED Requirements

### Requirement: 要約品質の一貫性
要約は一貫したフォーマットと品質で生成されなければならない (MUST)。プロンプトは`config/sources.yml`の`summarization.system_prompt`と`summarization.output_format`で完全にカスタマイズ可能でなければならない (MUST)。

#### Scenario: カスタムプロンプトによる要約生成
**Given** `config/sources.yml`に以下の設定がある:
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
**When** 記事が要約される
**Then** `system_prompt`と`output_format`がClaude APIのプロンプトに組み込まれる
**And** 記事データ（タイトル、URL、ソース、内容）がプロンプトに埋め込まれる
**And** 指定されたフォーマットに従って要約が生成される

#### Scenario: デフォルトプロンプトの使用
**Given** `config/sources.yml`に`summarization`セクションが存在しない、または`system_prompt`/`output_format`が指定されていない
**When** 要約処理が実行される
**Then** デフォルトの`system_prompt`が使用される
**And** デフォルトの`output_format`が使用される
**And** デフォルトプロンプトは標準的な要約（2-3文 + 箇条書き3点）を生成する

#### Scenario: 部分的なカスタマイズ
**Given** `config/sources.yml`に`system_prompt`のみが指定されている
```yaml
summarization:
  system_prompt: "カスタムシステムプロンプト"
```
**When** 要約処理が実行される
**Then** カスタム`system_prompt`が使用される
**And** デフォルトの`output_format`が使用される
**And** 両者が正しく組み合わされたプロンプトが生成される

## ADDED Requirements

### Requirement: カスタムプロンプト設定の検証
`config/sources.yml`で指定されたカスタムプロンプトは、起動時にバリデーションされなければならない (MUST)。

#### Scenario: 空のプロンプト検出
**Given** `config/sources.yml`に空の`system_prompt`が設定されている
```yaml
summarization:
  system_prompt: ""
```
**When** Configが初期化される
**Then** `ConfigurationError`例外が発生する
**And** エラーメッセージに「system_prompt must not be empty」が含まれる

#### Scenario: 空白のみのプロンプト検出
**Given** `config/sources.yml`に空白のみの`output_format`が設定されている
```yaml
summarization:
  output_format: "   \n  "
```
**When** Configが初期化される
**Then** `ConfigurationError`例外が発生する
**And** エラーメッセージに「output_format must not be empty or whitespace-only」が含まれる

#### Scenario: 最大長制限の検証
**Given** `config/sources.yml`に2000文字を超える`system_prompt`が設定されている
**When** Configが初期化される
**Then** `ConfigurationError`例外が発生する
**And** エラーメッセージに最大文字数が表示される

#### Scenario: 型の検証
**Given** `config/sources.yml`に数値や配列など、文字列以外の型が設定されている
```yaml
summarization:
  system_prompt: 123
```
**When** Configが初期化される
**Then** `ConfigurationError`例外が発生する
**And** エラーメッセージに「system_prompt must be a string」が含まれる

---

### Requirement: ログと可観測性
使用中のプロンプト設定がログに記録されなければならない (MUST)。

#### Scenario: カスタムプロンプト使用のログ記録
**Given** カスタム`system_prompt`と`output_format`が設定されている
**When** Summarizerが初期化される
**Then** ログに「Using custom summarization prompts」が記録される
**And** ログレベルは INFO

#### Scenario: デフォルトプロンプト使用のログ記録
**Given** カスタムプロンプトが設定されていない
**When** Summarizerが初期化される
**Then** ログに「Using default summarization prompts」が記録される
**And** ログレベルは INFO

#### Scenario: ドライラン実行での設定表示
**Given** カスタムプロンプトが設定されている
**When** `./bin/run --dry-run` を実行する
**Then** 標準出力に「Custom prompts configured」が表示される
**And** プロンプトの先頭50文字程度がプレビュー表示される
