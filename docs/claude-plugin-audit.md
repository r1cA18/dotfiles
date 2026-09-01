# Claude Plugin / Skill棚卸し

2026-08-25時点の宣言設定を基準にする。

## Source of truth

Claude pluginの有効状態は`nix/home-manager/programs/claude-code.nix`の`enabledPlugins`で管理する。

| plugin                                    | 用途                             |
| ----------------------------------------- | -------------------------------- |
| `antigravity@antigravity-for-claude-code` | Claude CodeからAntigravityを呼ぶ |
| `codex@openai-codex`                      | Claude CodeからCodexを呼ぶ       |

`~/.claude/plugins/installed_plugins.json`とcacheには過去に導入したpluginが残ることがある。これらはruntime生成物であり、有効pluginの正本にはしない。

## Skillとの境界

- ClaudeとCodexで共有するworkflowは`agents/skills/`または宣言済み外部skillに置く
- Claude固有のmarketplaceとpluginだけを`enabledPlugins`に置く
- runtime cacheは`dr`で削除しない
- `frontend-design`やdocument系skillは`agent-skills.nix`から共有する
- review workflowは共有`post-review` skillを使う

pluginを追加する場合はruntime installだけで終わらせず、継続利用するかを判断して宣言設定へ反映する。
