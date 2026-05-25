# Claude Plugin / Skill 棚卸し

2026-03-19 時点の `~/.claude/plugins/installed_plugins.json` と runtime cache をもとに整理。

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

| plugin                                 | 理由                                    |
| -------------------------------------- | --------------------------------------- |
| `hookify@claude-plugins-official`      | hooks / rules 作成支援で Claude 固有    |
| `figma@claude-plugins-official`        | plugin / MCP 依存が強い                 |
| `linear@claude-plugins-official`       | Codex では MCP で別管理                 |
| `aurochs-office@aurochs-claude-plugin` | Claude plugin 前提                      |
| `sharp-aircon@sharp-aircon-plugins`    | 個別ドメインで Codex 共通化の価値が低い |

## 共有化候補

| plugin / source                             | asset                   | コメント                                                  |
| ------------------------------------------- | ----------------------- | --------------------------------------------------------- |
| `pr-review-toolkit@claude-plugins-official` | review workflow         | `skills/post-review/` で代替の shared workflow を追加済み |
| `code-review@claude-code-plugins`           | review workflow         | `skills/post-review/` で代替可能                          |
| `document-skills@anthropic-agent-skills`    | `pdf`, `xlsx`           | 公式 skill として `agent-skills.nix` で有効化候補         |
| `document-skills@anthropic-agent-skills`    | `docx`, `pptx`          | 必要になったら公式 skill として有効化検討                 |
| `skill-creator@claude-plugins-official`     | skill creation guidance | Codex 側の system skill と役割が重複                      |

## 実態メモ

- plugin skill 本体は `~/.claude/plugins/marketplaces/...` または `~/.claude/plugins/cache/...` に展開される
- install 状態には `user` scope と `project` scope が混在している
- `frontend-design` は official plugin, claude-code-plugins, anthropic document-skills の複数ソースが混在していた

## 次の候補

1. `pdf` と `xlsx` を `agent-skills.nix` で有効化するか判断
2. Figma 系を共有 asset 化するなら plugin 依存を外した新しい skill を別途作る
3. review workflow は `post-review` を使って Claude command 依存を徐々に減らす
