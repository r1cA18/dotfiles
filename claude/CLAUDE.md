# Global Instructions

このファイルは全プロジェクトに適用されるグローバル指示。

## 言語

- 日本語で応答
- 敬語不使用（タメ口）
- 技術用語・コード識別子は原語のまま

## スキル作成

グローバルスキル（どのプロジェクトでも使うもの）を作成する場合:
- 保存先: `~/dotfiles/skills/<skill-name>/`
- 必須ファイル: `SKILL.md`
- `dr` でビルドすると `~/.claude/skills/` に同期される

## Git規約

- コミットメッセージ: 英語、Conventional Commits形式
  - `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- ブランチ名: `feature/xxx`, `fix/xxx`, `docs/xxx`
- mainへの直接pushは避ける（小さな修正を除く）

## コーディングスタイル

- シンプルさを優先
- 過度な抽象化を避ける
- 既存のコードスタイルに従う
- 不要なコメント・ドキュメントを追加しない

## ツール使用

- Codexの`review`コマンドを活用してコードレビュー
- 複雑な実装前にプランを立てる
- テスト駆動開発を推奨

## dotfiles変更時

- 変更後は `dr` でリビルド
- 詳細は `~/dotfiles/docs/architecture.md` を参照
