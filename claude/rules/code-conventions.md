# Code Conventions

## コード

- 絵文字禁止: コード、コメント、コミットメッセージ、Markdown 全てで絵文字を使わない
- シンプルさを優先、過度な抽象化を避ける
- 既存のコードスタイルに従う
- 不要なコメント・ドキュメントを追加しない
- 過剰に装飾された print/log 文を書かない（シンプルなデバッグ出力で十分）

## Git

- コミットメッセージ: 英語、Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- ブランチ名: `feature/xxx`, `fix/xxx`, `docs/xxx`
- main への直接 push は避ける（小さな修正を除く）
