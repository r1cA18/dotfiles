# Claude Plugin / Skill 棚卸し

2026-06-09 時点の `~/.claude/plugins/installed_plugins.json` と runtime cache をもとに整理。

## 方針

- `Codex` と共有したいものは `skills/` か project docs に移す
- Claude plugin 固有の runtime 拡張はそのまま Claude 専用に残す
- plugin の install 状態は source of truth にしない

## 共有済み

| plugin / source                           | asset                   | 対応                                          |
| ----------------------------------------- | ----------------------- | --------------------------------------------- |
| `frontend-design@claude-plugins-official` | `frontend-design` skill | `agent-skills.nix` で official skill を有効化 |
| `frontend-design@claude-code-plugins`     | `frontend-design` skill | official skill に寄せて一本化                 |

## 継続して Claude 専用に残すもの

| plugin                                   | 理由                                 |
| ---------------------------------------- | ------------------------------------ |
| `codex@openai-codex`                     | Claude Code から Codex を呼ぶ bridge |
| `swift-lsp@claude-plugins-official`      | iOS pack の Claude 専用補助          |
| `typescript-lsp@claude-plugins-official` | web pack の Claude 専用補助          |

## 共有化候補

| plugin / source                             | asset                   | コメント                                            |
| ------------------------------------------- | ----------------------- | --------------------------------------------------- |
| `pr-review-toolkit@claude-plugins-official` | review workflow         | `skills/post-review/` で代替                        |
| `code-review@claude-code-plugins`           | review workflow         | `skills/post-review/` で代替                        |
| `document-skills@anthropic-agent-skills`    | `pdf`, `xlsx`           | `agent-skills.nix` で shared skill として有効化済み |
| `skill-creator@claude-plugins-official`     | skill creation guidance | Codex 側の system skill と役割が重複                |

## 削除・無効化方針

| plugin                                         | 判断                                                     |
| ---------------------------------------------- | -------------------------------------------------------- |
| `ralph-loop` / `ralph-wiggum`                  | Codex subagents / goal workflow で代替。不要             |
| `figma@claude-plugins-official`                | 現運用では不要                                           |
| `linear@claude-plugins-official`               | 現運用では不要。必要なら Codex MCP / plugin で再検討     |
| `context7@claude-plugins-official`             | 現運用では不要。必要時はWeb/公式docs/個別MCPで対応       |
| `commit-commands@claude-plugins-official`      | git workflow は通常コマンドと GitHub plugin skill で代替 |
| `claude-md-management@claude-plugins-official` | project docs / shared instructions で代替                |
| `claude-code-setup@claude-plugins-official`    | dotfiles の project init / pack 設計で代替               |
| `hookify@claude-plugins-official`              | 作った hook 自体だけを必要に応じて移植                   |
| `playground@claude-plugins-official`           | Codex/browser/frontend skills で代替                     |
| `frontend-design@claude-plugins-official`      | shared `frontend-design` skill で代替                    |

## 実態メモ

- plugin skill 本体は `~/.claude/plugins/marketplaces/...` または `~/.claude/plugins/cache/...` に展開される
- install 状態には `user` scope と `project` scope が混在している
- `frontend-design` は official plugin, claude-code-plugins, anthropic document-skills の複数ソースが混在していた

## 次の候補

1. review workflow は `post-review` を使って Claude command 依存を徐々に減らす
2. 必要になった外部連携だけ Codex plugin / MCP / shared skill として個別追加する
