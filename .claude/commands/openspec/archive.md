---
name: OpenSpec: Archive
description: Archive a deployed OpenSpec change and update specs.
category: OpenSpec
tags: [openspec, archive]
---
<!-- OPENSPEC:START -->
**ガードレール**
- まず単純で最小限の実装を優先し、明示的に要求されるか明確に必要な場合にのみ複雑さを追加する。
- 変更を要求された結果に厳密にスコープする。
- 追加の OpenSpec 規約または明確化が必要な場合は、`openspec/AGENTS.md`（`openspec/` ディレクトリ内にあります—表示されない場合は `ls openspec` または `openspec update` を実行）を参照してください。

**ステップ**
1. アーカイブする変更 ID を決定する:
   - このプロンプトにすでに特定の変更 ID が含まれている場合（例: スラッシュコマンド引数によって入力された `<ChangeId>` ブロック内）、空白をトリミングした後にその値を使用します。
   - 会話が変更を緩く参照している場合（例: タイトルまたは要約による）、`openspec list` を実行して可能性のある ID を表示し、関連する候補を共有し、ユーザーがどれを意図しているかを確認します。
   - それ以外の場合は、会話を確認し、`openspec list` を実行し、ユーザーにどの変更をアーカイブするかを尋ねます; 進む前に確認された変更 ID を待ちます。
   - 単一の変更 ID をまだ特定できない場合は、停止してユーザーにまだ何もアーカイブできないことを伝えます。
2. `openspec list`（または `openspec show <id>`）を実行して変更 ID を検証し、変更が欠落している場合、すでにアーカイブされている場合、またはアーカイブの準備ができていない場合は停止します。
3. `openspec archive <id> --yes` を実行して、CLI が変更を移動し、プロンプトなしで仕様更新を適用するようにします（ツール専用の作業の場合のみ `--skip-specs` を使用）。
4. コマンド出力を確認して、ターゲット仕様が更新され、変更が `changes/archive/` に到達したことを確認します。
5. `openspec validate --strict` で検証し、何かおかしい場合は `openspec show <id>` で検査します。

**リファレンス**
- アーカイブする前に `openspec list` を使用して変更 ID を確認してください。
- `openspec list --specs` で更新された仕様を検査し、引き渡す前に検証の問題に対処してください。
<!-- OPENSPEC:END -->
