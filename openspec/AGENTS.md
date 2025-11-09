# OpenSpec 指示書

OpenSpec を使用した仕様駆動開発のための AI コーディングアシスタント向けの指示です。

## TL;DR クイックチェックリスト

- 既存の作業を検索: `openspec spec list --long`, `openspec list`（全文検索には `rg` のみを使用）
- スコープを決定: 新しい capability か既存の capability の変更か
- ユニークな `change-id` を選択: kebab-case、動詞から始まる（`add-`, `update-`, `remove-`, `refactor-`）
- スキャフォールド: `proposal.md`, `tasks.md`, `design.md`（必要な場合のみ）、および影響を受ける capability ごとの差分仕様
- 差分を記述: `## ADDED|MODIFIED|REMOVED|RENAMED Requirements` を使用し、要件ごとに少なくとも 1 つの `#### Scenario:` を含める
- 検証: `openspec validate [change-id] --strict` を実行し、問題を修正
- 承認を要求: 提案が承認されるまで実装を開始しない

## 3 段階のワークフロー

### ステージ 1: 変更の作成
以下の場合に提案を作成:
- 機能を追加する
- 破壊的変更を行う（API、スキーマ）
- アーキテクチャやパターンを変更する
- パフォーマンスを最適化する（動作を変更する）
- セキュリティパターンを更新する

トリガー（例）:
- 「変更提案を作成して」
- 「変更を計画して」
- 「提案を作成して」
- 「仕様提案を作成したい」
- 「仕様を作成したい」

緩い一致ガイダンス:
- 以下のいずれかを含む: `proposal`, `change`, `spec`
- 以下のいずれかと組み合わせ: `create`, `plan`, `make`, `start`, `help`

提案をスキップする場合:
- バグ修正（意図した動作を復元）
- タイポ、フォーマット、コメント
- 依存関係の更新（非破壊的）
- 設定変更
- 既存の動作のテスト

**ワークフロー**
1. `openspec/project.md`, `openspec list`, `openspec list --specs` を確認して、現在のコンテキストを理解する
2. ユニークな動詞主導の `change-id` を選択し、`openspec/changes/<id>/` 配下に `proposal.md`, `tasks.md`, オプションの `design.md`、および仕様の差分をスキャフォールドする
3. `## ADDED|MODIFIED|REMOVED Requirements` を使用して仕様の差分を下書きし、要件ごとに少なくとも 1 つの `#### Scenario:` を含める
4. `openspec validate <id> --strict` を実行し、提案を共有する前にすべての問題を解決する

### ステージ 2: 変更の実装
以下の手順を TODO として追跡し、1 つずつ完了する:
1. **proposal.md を読む** - 何が構築されるかを理解する
2. **design.md を読む**（存在する場合） - 技術的な決定を確認する
3. **tasks.md を読む** - 実装チェックリストを取得する
4. **タスクを順次実装** - 順番に完了する
5. **完了を確認** - ステータスを更新する前に `tasks.md` のすべての項目が完了していることを確認する
6. **チェックリストを更新** - すべての作業が完了した後、すべてのタスクを `- [x]` に設定し、リストが現実を反映するようにする
7. **承認ゲート** - 提案がレビューされ承認されるまで実装を開始しない

### ステージ 3: 変更のアーカイブ
デプロイ後、別の PR を作成:
- `changes/[name]/` → `changes/archive/YYYY-MM-DD-[name]/` に移動
- capability が変更された場合は `specs/` を更新
- ツール専用の変更には `openspec archive <change-id> --skip-specs --yes` を使用（常に change ID を明示的に渡す）
- `openspec validate --strict` を実行して、アーカイブされた変更がチェックに合格することを確認する

## 任意のタスクの前に

**コンテキストチェックリスト:**
- [ ] `specs/[capability]/spec.md` で関連する仕様を読む
- [ ] `changes/` で競合する保留中の変更をチェックする
- [ ] `openspec/project.md` で規約を読む
- [ ] `openspec list` を実行してアクティブな変更を確認する
- [ ] `openspec list --specs` を実行して既存の capability を確認する

**仕様を作成する前に:**
- capability がすでに存在するかどうかを常に確認する
- 重複を作成するよりも既存の仕様を変更することを優先する
- `openspec show [spec]` を使用して現在の状態を確認する
- リクエストが曖昧な場合は、スキャフォールドする前に 1〜2 つの明確化質問をする

### 検索ガイダンス
- 仕様を列挙: `openspec spec list --long`（スクリプトには `--json`）
- 変更を列挙: `openspec list`（または `openspec change list --json` - 非推奨だが利用可能）
- 詳細を表示:
  - 仕様: `openspec show <spec-id> --type spec`（フィルターには `--json` を使用）
  - 変更: `openspec show <change-id> --json --deltas-only`
- 全文検索（ripgrep を使用）: `rg -n "Requirement:|Scenario:" openspec/specs`

## クイックスタート

### CLI コマンド

```bash
# 必須コマンド
openspec list                  # アクティブな変更をリスト
openspec list --specs          # 仕様をリスト
openspec show [item]           # 変更または仕様を表示
openspec validate [item]       # 変更または仕様を検証
openspec archive <change-id> [--yes|-y]   # デプロイ後にアーカイブ（非対話的実行には --yes を追加）

# プロジェクト管理
openspec init [path]           # OpenSpec を初期化
openspec update [path]         # 指示ファイルを更新

# 対話モード
openspec show                  # 選択を促す
openspec validate              # 一括検証モード

# デバッグ
openspec show [change] --json --deltas-only
openspec validate [change] --strict
```

### コマンドフラグ

- `--json` - 機械可読出力
- `--type change|spec` - 項目を明確化
- `--strict` - 包括的な検証
- `--no-interactive` - プロンプトを無効化
- `--skip-specs` - 仕様更新なしでアーカイブ
- `--yes`/`-y` - 確認プロンプトをスキップ（非対話的アーカイブ）

## ディレクトリ構造

```
openspec/
├── project.md              # プロジェクトの規約
├── specs/                  # 現在の真実 - 構築されたもの
│   └── [capability]/       # 単一の焦点を持つ capability
│       ├── spec.md         # 要件とシナリオ
│       └── design.md       # 技術的なパターン
├── changes/                # 提案 - 変更すべきもの
│   ├── [change-name]/
│   │   ├── proposal.md     # なぜ、何を、影響
│   │   ├── tasks.md        # 実装チェックリスト
│   │   ├── design.md       # 技術的な決定（オプション; 基準を参照）
│   │   └── specs/          # 差分変更
│   │       └── [capability]/
│   │           └── spec.md # ADDED/MODIFIED/REMOVED
│   └── archive/            # 完了した変更
```

## 変更提案の作成

### 決定木

```
新しいリクエスト?
├─ 仕様の動作を復元するバグ修正? → 直接修正
├─ タイポ/フォーマット/コメント? → 直接修正
├─ 新機能/capability? → 提案を作成
├─ 破壊的変更? → 提案を作成
├─ アーキテクチャの変更? → 提案を作成
└─ 不明確? → 提案を作成（より安全）
```

### 提案の構造

1. **ディレクトリを作成:** `changes/[change-id]/`（kebab-case、動詞主導、ユニーク）

2. **proposal.md を書く:**
```markdown
# 変更: [変更の簡単な説明]

## なぜ
[問題/機会について 1〜2 文]

## 何が変わるか
- [変更のリスト]
- [破壊的変更には **BREAKING** とマーク]

## 影響
- 影響を受ける仕様: [capability をリスト]
- 影響を受けるコード: [主要なファイル/システム]
```

3. **仕様の差分を作成:** `specs/[capability]/spec.md`
```markdown
## ADDED Requirements
### Requirement: 新機能
システムは...を提供しなければならない

#### Scenario: 成功ケース
- **WHEN** ユーザーがアクションを実行する
- **THEN** 期待される結果

## MODIFIED Requirements
### Requirement: 既存機能
[完全な変更された要件]

## REMOVED Requirements
### Requirement: 古い機能
**理由**: [なぜ削除するか]
**移行**: [どのように処理するか]
```
複数の capability が影響を受ける場合、`changes/[change-id]/specs/<capability>/spec.md` 配下に複数の差分ファイルを作成します—capability ごとに 1 つ。

4. **tasks.md を作成:**
```markdown
## 1. 実装
- [ ] 1.1 データベーススキーマを作成
- [ ] 1.2 API エンドポイントを実装
- [ ] 1.3 フロントエンドコンポーネントを追加
- [ ] 1.4 テストを書く
```

5. **必要に応じて design.md を作成:**
以下のいずれかが該当する場合は `design.md` を作成し、それ以外の場合は省略します:
- 横断的な変更（複数のサービス/モジュール）または新しいアーキテクチャパターン
- 新しい外部依存関係または重要なデータモデルの変更
- セキュリティ、パフォーマンス、または移行の複雑さ
- コーディング前に技術的な決定から恩恵を受ける曖昧さ

最小限の `design.md` スケルトン:
```markdown
## コンテキスト
[背景、制約、ステークホルダー]

## 目標 / 非目標
- 目標: [...]
- 非目標: [...]

## 決定
- 決定: [何をそしてなぜ]
- 検討した代替案: [オプション + 根拠]

## リスク / トレードオフ
- [リスク] → 軽減

## 移行計画
[ステップ、ロールバック]

## 未解決の質問
- [...]
```

## 仕様ファイル形式

### 重要: シナリオのフォーマット

**正しい**（#### ヘッダーを使用）:
```markdown
#### Scenario: ユーザーログイン成功
- **WHEN** 有効な認証情報が提供される
- **THEN** JWT トークンを返す
```

**間違い**（箇条書きや太字を使用しない）:
```markdown
- **Scenario: ユーザーログイン**  ❌
**Scenario**: ユーザーログイン     ❌
### Scenario: ユーザーログイン      ❌
```

すべての要件には少なくとも 1 つのシナリオが必要です。

### 要件の文言
- 規範的要件には SHALL/MUST を使用する（意図的に非規範的でない限り should/may を避ける）

### 差分操作

- `## ADDED Requirements` - 新しい capability
- `## MODIFIED Requirements` - 変更された動作
- `## REMOVED Requirements` - 非推奨の機能
- `## RENAMED Requirements` - 名前の変更

ヘッダーは `trim(header)` でマッチング - 空白は無視されます。

#### ADDED と MODIFIED の使い分け
- ADDED: 要件として単独で存在できる新しい capability またはサブ capability を導入します。変更が直交している場合（例：「Slash Command Configuration」の追加）は、既存の要件のセマンティクスを変更するのではなく、ADDED を優先します。
- MODIFIED: 既存の要件の動作、スコープ、または受け入れ基準を変更します。常に完全な更新された要件の内容（ヘッダー + すべてのシナリオ）を貼り付けます。アーカイバーはここで提供するもので要件全体を置き換えます; 部分的な差分は以前の詳細をドロップします。
- RENAMED: 名前のみが変更される場合に使用します。動作も変更する場合は、RENAMED（名前）と MODIFIED（内容）を新しい名前を参照して使用します。

よくある落とし穴: 以前のテキストを含めずに MODIFIED を使用して新しい懸念を追加すること。これによりアーカイブ時に詳細が失われます。既存の要件を明示的に変更していない場合は、代わりに ADDED の下に新しい要件を追加してください。

MODIFIED 要件を正しく作成する:
1) `openspec/specs/<capability>/spec.md` で既存の要件を見つけます。
2) 要件ブロック全体（`### Requirement: ...` からそのシナリオまで）をコピーします。
3) `## MODIFIED Requirements` の下に貼り付け、新しい動作を反映するように編集します。
4) ヘッダーテキストが正確に一致することを確認し（空白は区別しない）、少なくとも 1 つの `#### Scenario:` を保持します。

RENAMED の例:
```markdown
## RENAMED Requirements
- FROM: `### Requirement: Login`
- TO: `### Requirement: User Authentication`
```

## トラブルシューティング

### よくあるエラー

**"Change must have at least one delta"**
- `changes/[name]/specs/` が .md ファイルとともに存在することを確認
- ファイルに操作プレフィックス（## ADDED Requirements）があることを確認

**"Requirement must have at least one scenario"**
- シナリオが `#### Scenario:` 形式（4 つのハッシュ）を使用していることを確認
- シナリオヘッダーに箇条書きや太字を使用しない

**サイレントシナリオ解析の失敗**
- 正確な形式が必要: `#### Scenario: Name`
- デバッグ: `openspec show [change] --json --deltas-only`

### 検証のヒント

```bash
# 常に厳密モードを使用して包括的なチェックを行う
openspec validate [change] --strict

# 差分解析をデバッグ
openspec show [change] --json | jq '.deltas'

# 特定の要件をチェック
openspec show [spec] --json -r 1
```

## ハッピーパススクリプト

```bash
# 1) 現在の状態を調査
openspec spec list --long
openspec list
# オプションの全文検索:
# rg -n "Requirement:|Scenario:" openspec/specs
# rg -n "^#|Requirement:" openspec/changes

# 2) 変更 ID を選択してスキャフォールド
CHANGE=add-two-factor-auth
mkdir -p openspec/changes/$CHANGE/{specs/auth}
printf "## なぜ\n...\n\n## 何が変わるか\n- ...\n\n## 影響\n- ...\n" > openspec/changes/$CHANGE/proposal.md
printf "## 1. 実装\n- [ ] 1.1 ...\n" > openspec/changes/$CHANGE/tasks.md

# 3) 差分を追加（例）
cat > openspec/changes/$CHANGE/specs/auth/spec.md << 'EOF'
## ADDED Requirements
### Requirement: 二要素認証
ユーザーはログイン時に第二要素を提供しなければならない。

#### Scenario: OTP が必要
- **WHEN** 有効な認証情報が提供される
- **THEN** OTP チャレンジが必要
EOF

# 4) 検証
openspec validate $CHANGE --strict
```

## 複数 Capability の例

```
openspec/changes/add-2fa-notify/
├── proposal.md
├── tasks.md
└── specs/
    ├── auth/
    │   └── spec.md   # ADDED: 二要素認証
    └── notifications/
        └── spec.md   # ADDED: OTP メール通知
```

auth/spec.md
```markdown
## ADDED Requirements
### Requirement: 二要素認証
...
```

notifications/spec.md
```markdown
## ADDED Requirements
### Requirement: OTP メール通知
...
```

## ベストプラクティス

### シンプルさ第一
- デフォルトで 100 行未満の新しいコード
- 不十分であることが証明されるまでは単一ファイル実装
- 明確な正当化なしにフレームワークを避ける
- 退屈で実証済みのパターンを選択

### 複雑さのトリガー
以下の場合にのみ複雑さを追加:
- 現在のソリューションが遅すぎることを示すパフォーマンスデータ
- 具体的なスケール要件（>1000 ユーザー、>100MB データ）
- 抽象化を必要とする複数の実証されたユースケース

### 明確な参照
- コードの場所には `file.ts:42` 形式を使用
- 仕様を `specs/auth/spec.md` として参照
- 関連する変更と PR をリンク

### Capability の命名
- 動詞-名詞を使用: `user-auth`, `payment-capture`
- capability ごとに単一の目的
- 10 分の理解可能性ルール
- 説明に「AND」が必要な場合は分割

### 変更 ID の命名
- kebab-case を使用し、短く説明的: `add-two-factor-auth`
- 動詞主導のプレフィックスを優先: `add-`, `update-`, `remove-`, `refactor-`
- 一意性を確保; 取得されている場合は `-2`, `-3` などを追加

## ツール選択ガイド

| タスク | ツール | 理由 |
|------|------|-----|
| パターンでファイルを検索 | Glob | 高速パターンマッチング |
| コードコンテンツを検索 | Grep | 最適化された正規表現検索 |
| 特定のファイルを読む | Read | 直接ファイルアクセス |
| 不明なスコープを調査 | Task | 複数ステップの調査 |

## エラー回復

### 変更の競合
1. `openspec list` を実行してアクティブな変更を確認
2. 重複する仕様をチェック
3. 変更オーナーと調整
4. 提案の結合を検討

### 検証の失敗
1. `--strict` フラグで実行
2. JSON 出力で詳細をチェック
3. 仕様ファイル形式を確認
4. シナリオが適切にフォーマットされていることを確認

### 欠落したコンテキスト
1. 最初に project.md を読む
2. 関連する仕様をチェック
3. 最近のアーカイブを確認
4. 明確化を求める

## クイックリファレンス

### ステージインジケーター
- `changes/` - 提案、まだ構築されていない
- `specs/` - 構築およびデプロイ済み
- `archive/` - 完了した変更

### ファイルの目的
- `proposal.md` - なぜと何を
- `tasks.md` - 実装ステップ
- `design.md` - 技術的な決定
- `spec.md` - 要件と動作

### CLI の基本
```bash
openspec list              # 進行中のものは?
openspec show [item]       # 詳細を表示
openspec validate --strict # 正しいか?
openspec archive <change-id> [--yes|-y]  # 完了としてマーク（自動化には --yes を追加）
```

覚えておいてください: 仕様は真実です。変更は提案です。それらを同期させ続けてください。
