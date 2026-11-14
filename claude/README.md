# Claude Code設定

`~/.claude/`の設定をNixとrepository fileで宣言的に管理する。
user-level runtime stateの一部は`~/.claude.json`に別保存される。
Claude Code本体はnative installer版を使う。Home Managerは未導入時のbootstrapとversion channelと設定を管理する。

## 構造

```text
~/.claude/
├── CLAUDE.md            ← agents/{INSTRUCTIONS.md,rules/*}をNixで結合
├── settings.json        ← writable。claude-code.nixの管理keyをmerge
├── settings.local.json  ← runtime生成（管理対象外）
├── managed-channel      ← Claude Code更新channelをNix生成
├── rules/               ← claude/rules/へのsymlink
├── hooks/               ← claude/hooks/へのsymlink
├── commands/            ← claude/commands/へのsymlink
├── agents/              ← claude/agents/へのfile単位symlink
└── skills/              ← r1hnがcatalogのentryごとにsymlink

~/.claude.json           ← user-level runtime state（管理対象外）
```

## 管理境界

| 対象               | Source of truth                             | 反映方法 |
| ------------------ | ------------------------------------------- | -------- |
| `CLAUDE.md`        | `agents/INSTRUCTIONS.md`と`agents/rules/`   | `dr`     |
| `settings.json`    | `nix/home-manager/programs/claude-code.nix` | `dr`     |
| `managed-channel`  | 同上                                        | `dr`     |
| `rules/`           | `claude/rules/`                             | 即時     |
| `hooks/`           | `claude/hooks/`                             | 即時     |
| `commands/`        | `claude/commands/`                          | 即時     |
| `agents/`          | `claude/agents/`                            | 即時     |
| `skills/`          | `agents/capabilities/catalog.nix`           | `dr`     |

共有instructionはClaudeとCodexの両方へ配布する。Claude固有のrule・hook・command・agentだけを`claude/`へ置く。

## settings.json

`settings.json`はwritableなregular fileにする。Claude Codeはplugin導入や`/config`で書き換えるため、Home Managerはfileを所有しない。
毎回の`dr`が`nix/home-manager/programs/claude-code.nix`の`claudeSettings`のkeyをmergeする(`agents/scripts/merge-managed.py`)。
宣言したkeyは宣言値へ戻り、宣言していないkey(Claude Codeの中で有効にしたpluginなど)は残る。宣言から外したkeyは次の`dr`で消える。

## Binary更新

初回の`dr`は公式installerで`~/.local/bin/claude`をbootstrapする。background auto-updateは無効化してある。`dot update`の`claude-code`段階が`~/.claude/managed-channel`を読み、明示的に更新する。versionを固定する場合は`claude-code.nix`の`claudeChannel`を変更して`dr`する。

## MCP管理

MCP serverは`agents/capabilities/catalog.nix`に宣言する。`r1hn`が既定dirと各account dirの`.claude.json`の`mcpServers`へmergeし、自分が書いたkeyだけを消す。
Claude Codeの中で追加したserverは残る。`r1hn capability doctor`がcatalog外のserverを一覧し、`adopt NAME`がcatalogへ貼るattrsetを出す。

## Pluginとskill

有効にするpluginは`agents/capabilities/catalog.nix`の`kind = "plugin"`で宣言し、`r1hn`が`enabledPlugins`と`extraKnownMarketplaces`へmergeする。plugin本体と認証状態はClaude Codeがruntime展開する。

- Claude/Codexで共有するskill: `agents/skills/`
- Claude専用plugin: `agents/capabilities/catalog.nix`(marketplaceの宣言だけは`claude-code.nix`)
- 外部skill source: `flake.nix`と`nix/home-manager/programs/agent-skills.nix`

## Commandとagentの追加

新しいslash commandは`claude/commands/<name>.md`へ置く。新しいcustom agentは`claude/agents/<name>.md`へ置く。どちらもout-of-store symlinkなので`dr`せず反映される。

accountの追加と切り替えは[r1hnガイド](../docs/guides/r1hn.md)を参照する。

## 注意

- `settings.local.json`はmachine-local runtime設定としてGit管理しない
- `~/.claude.json`は認証とruntime stateを含むため完全管理しない
- Nix生成fileを直接編集せずsource of truthを変更する
- secretはrepositoryやNix storeへ入れない
