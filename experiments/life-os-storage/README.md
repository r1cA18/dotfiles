# Life OS storage lab

既存vaultを変更せず、検証用バックアップからLife OSの保存モデルを試す実装。DB正本、blob保管、出典、revision、意図とtaskの状態、全文検索、Markdown exportを分離する。

## 実行

```bash
python3 backup.py /path/to/vault /path/to/new-backup
bun run cli import /path/to/new-data /path/to/backup
bun run cli stats /path/to/new-data
bun run evaluate /path/to/backup /path/to/new-evaluation
bun run cli serve /path/to/new-data
```

バックアップの`manifest.json`は各通常ファイルのSHA-256を含む。importは検証済みmanifestだけを受け付ける。隠しファイル・agent設定・symlinkはimport対象外だが、バックアップには残る。

`10_Daily`のTimes見出しは、本文を保持したまま独立したTimes recordへ試験的に分割する。フォルダによるProject/Area分類は推定membershipであり、実データを無条件に確定知識へ昇格させない。

## 保証と制限

- 同一入力の再送はsource keyで冪等化する
- 訂正はrevision conflictを検出し派生recordをstaleにする
- agentのknowledge・intent・task提案は根拠を必須とする
- taskはowner authorizationなしに実行可能状態へ遷移できない
- export/restoreはcanonical tableとblobのchecksumを検証する
- 日本語検索はtrigramと短語のliteral fallbackを使う
- semanticな話題統合・STT・LLM・自動実行はこのlabの対象外
- localhost APIは読み取り専用であり認証付き公開運用には未対応
