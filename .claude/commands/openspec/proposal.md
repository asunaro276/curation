---
name: OpenSpec: Proposal
description: Scaffold a new OpenSpec change and validate strictly.
category: OpenSpec
tags: [openspec, change]
---
<!-- OPENSPEC:START -->
**ガードレール**
- まず単純で最小限の実装を優先し、明示的に要求されるか明確に必要な場合にのみ複雑さを追加する。
- 変更を要求された結果に厳密にスコープする。
- 追加の OpenSpec 規約または明確化が必要な場合は、`openspec/AGENTS.md`（`openspec/` ディレクトリ内にあります—表示されない場合は `ls openspec` または `openspec update` を実行）を参照してください。
- ファイルを編集する前に、曖昧または不明確な詳細を特定し、必要なフォローアップ質問をしてください。

**ステップ**
1. `openspec/project.md` を確認し、`openspec list` と `openspec list --specs` を実行し、関連するコードまたはドキュメント（例: `rg`/`ls` 経由）を検査して、提案を現在の動作に基づかせる; 明確化が必要なギャップに注意してください。
2. ユニークな動詞主導の `change-id` を選択し、`openspec/changes/<id>/` 配下に `proposal.md`, `tasks.md`, `design.md`（必要な場合）をスキャフォールドする。
3. 変更を具体的な capability または要件にマッピングし、複数スコープの取り組みを明確な関係とシーケンスを持つ個別の仕様差分に分割する。
4. ソリューションが複数のシステムにまたがる場合、新しいパターンを導入する場合、または仕様にコミットする前にトレードオフの議論を必要とする場合は、`design.md` でアーキテクチャの推論をキャプチャする。
5. `changes/<id>/specs/<capability>/spec.md`（capability ごとに 1 つのフォルダ）に仕様差分を下書きし、`## ADDED|MODIFIED|REMOVED Requirements` を使用し、要件ごとに少なくとも 1 つの `#### Scenario:` を含め、関連する capability を相互参照する。
6. `tasks.md` を、ユーザーに見える進捗を提供し、検証（テスト、ツール）を含み、依存関係または並列化可能な作業を強調する、小さく検証可能な作業項目の順序付きリストとして下書きする。
7. `openspec validate <id> --strict` で検証し、提案を共有する前にすべての問題を解決する。

**リファレンス**
- 検証が失敗した場合は、`openspec show <id> --json --deltas-only` または `openspec show <spec> --type spec` を使用して詳細を検査してください。
- 新しい要件を書く前に、`rg -n "Requirement:|Scenario:" openspec/specs` で既存の要件を検索してください。
- 提案が現在の実装の現実と一致するように、`rg <keyword>`, `ls`, または直接ファイル読み取りでコードベースを探索してください。
<!-- OPENSPEC:END -->
