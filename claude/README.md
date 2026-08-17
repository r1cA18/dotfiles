# Claude Code設定

`~/.claude/`の設定をNixとrepository fileで宣言的に管理する。
user-level runtime stateの一部は`~/.claude.json`に別保存される。
Claude Code本体はnative install前提で、Nixはversion channelと設定を管理する。

## 構造

```text
~/.claude/
├── CLAUDE.md            ← agents/{INSTRUCTIONS.md,rules/*}をNixで結合
├── settings.json        ← nix/home-manager/programs/claude-code.nixからNix生成
├── mcp-servers.json     ← claude/mcp-servers.jsonへのsymlink
├── settings.local.json  ← runtime生成（管理対象外）
├── managed-channel      ← Claude Code更新channelをNix生成
├── rules/               ← claude/rules/へのsymlink
├── hooks/               ← claude/hooks/へのsymlink
├── commands/            ← claude/commands/へのsymlink
├── agents/              ← claude/agents/へのfile単位symlink
└── skills/              ← agent-skills-nixから配布

~/.claude.json           ← user-level runtime state（管理対象外）
```

## 管理境界

| 対象               | Source of truth                             | 反映方法 |
| ------------------ | ------------------------------------------- | -------- |
| `CLAUDE.md`        | `agents/INSTRUCTIONS.md`と`agents/rules/`   | `dr`     |
| `settings.json`    | `nix/home-manager/programs/claude-code.nix` | `dr`     |
| `managed-channel`  | 同上                                        | `dr`     |
| `mcp-servers.json` | `claude/mcp-servers.json`                   | 即時     |
| `rules/`           | `claude/rules/`                             | 即時     |
| `hooks/`           | `claude/hooks/`                             | 即時     |
| `commands/`        | `claude/commands/`                          | 即時     |
| `agents/`          | `claude/agents/`                            | 即時     |
| `skills/`          | `agents/skills/`と宣言済み外部source        | `dr`     |

共有instructionはClaudeとCodexの両方へ配布する。Claude固有のrule・hook・command・agentだけを`claude/`へ置く。

## settings.json

`settings.json`はrepository内のJSON fileではない。Home Manager moduleが次を含むJSONを生成し、Nix storeへのsymlinkとして配置する。

```json
{
  "model": "claude-opus-4-6",
  "hooks": {},
  "enabledPlugins": {},
  "language": "日本語, 敬語非使用",
  "permissions": {}
}
```

Claude Codeが`settings.json`を書き換えてregular fileにした場合も、次回の`dr`でNix宣言へ戻す。恒久変更は`nix/home-manager/programs/claude-code.nix`へ入れる。

## Binary更新

Linuxでは公式installerで`~/.local/bin/claude`へ入れる。

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

background auto-updateは無効化してある。`du`が`~/.claude/managed-channel`を読み、`update-claude-code`経由で明示的に更新する。versionを固定する場合は`claude-code.nix`の`claudeChannel`を変更して`dr`する。

## MCP管理

ClaudeのMCP実設定は`~/.claude.json`にあり、OAuth状態などのruntime情報も含む。そのためfile全体をNix管理せず、`claude/mcp-servers.json`をdeclarative seedにする。

```bash
python3 ~/dotfiles/claude/scripts/sync-mcp-servers.py \
  ~/.claude.json \
  ~/dotfiles/claude/mcp-servers.json
```

このscriptは`mcpServers`だけをupsertし、他のruntime stateは残す。`dr`でも同じ同期を実行する。

## Pluginとskill

`enabledPlugins`は`claude-code.nix`で宣言する。plugin本体と認証状態はClaude Codeがruntime展開する。

- Claude/Codexで共有するskill: `agents/skills/`
- Claude専用plugin: `nix/home-manager/programs/claude-code.nix`
- 外部skill source: `flake.nix`と`nix/home-manager/programs/agent-skills.nix`

## Commandとagentの追加

新しいslash commandは`claude/commands/<name>.md`へ置く。新しいcustom agentは`claude/agents/<name>.md`へ置く。どちらもout-of-store symlinkなので`dr`せず反映される。

## 注意

- `settings.local.json`はmachine-local runtime設定としてGit管理しない
- `~/.claude.json`は認証とruntime stateを含むため完全管理しない
- Nix生成fileを直接編集せずsource of truthを変更する
- secretはrepositoryやNix storeへ入れない
