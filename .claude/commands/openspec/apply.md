---
name: OpenSpec: Apply
description: Implement an approved OpenSpec change and keep tasks in sync.
category: OpenSpec
tags: [openspec, apply]
---
<!-- OPENSPEC:START -->
**ガードレール**
- まず単純で最小限の実装を優先し、明示的に要求されるか明確に必要な場合にのみ複雑さを追加する。
- 変更を要求された結果に厳密にスコープする。
- 追加の OpenSpec 規約または明確化が必要な場合は、`openspec/AGENTS.md`（`openspec/` ディレクトリ内にあります—表示されない場合は `ls openspec` または `openspec update` を実行）を参照してください。

**ステップ**
これらのステップを TODO として追跡し、1 つずつ完了します。
1. `changes/<id>/proposal.md`, `design.md`（存在する場合）, `tasks.md` を読み、スコープと受け入れ基準を確認する。
2. タスクを順次処理し、編集を最小限に抑え、要求された変更に焦点を当てる。
3. ステータスを更新する前に完了を確認する—`tasks.md` のすべての項目が完了していることを確認する。
4. すべての作業が完了した後にチェックリストを更新し、各タスクが `- [x]` とマークされ、現実を反映するようにする。
5. 追加のコンテキストが必要な場合は、`openspec list` または `openspec show <item>` を参照する。

**リファレンス**
- 実装中に提案から追加のコンテキストが必要な場合は、`openspec show <id> --json --deltas-only` を使用してください。
<!-- OPENSPEC:END -->
