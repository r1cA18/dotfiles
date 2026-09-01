# Agent account profile管理

Claude CodeとCodexのaccountは同じ方式で切り替える。
公開dotfilesにはaccountのemailやcredentialを保存しない。

## 起動方法

```bash
# fzfでaccountを選択
cl
cx

# emailを直接指定
cl user@example.com
cx user@example.com

# Tabで登録済みemailを補完
cl <Tab>
cx <Tab>
```

`cl`は`clp run`へ展開される。`cx`は`cxp run`へ展開される。
profile管理commandを直接使う場合は以下になる。

```bash
clp list
clp add user@example.com
clp login user@example.com
clp status user@example.com
clp path user@example.com

cxp list
cxp add user@example.com
cxp login user@example.com
cxp status user@example.com
cxp path user@example.com
```

`run`・`login`・`status`・`path`でemailを省略するとfzf pickerが開く。

## 保存場所

```text
Claude primary       ~/.claude + ~/.claude.json
Claude追加profile    ${XDG_STATE_HOME:-~/.local/state}/claude-code/profiles/<email>

Codex primary        ~/.codex
Codex追加profile     ${XDG_STATE_HOME:-~/.local/state}/codex/profiles/<email>
```

追加accountはemailをdirectory名にしてstate directoryへ追加する。

## 管理境界

| 種類               | Claude Code                                      | Codex                                     | 管理方法            |
| ------------------ | ------------------------------------------------ | ----------------------------------------- | ------------------- |
| global instruction | `CLAUDE.md`                                      | `AGENTS.md`                               | primaryから共有link |
| user config        | `settings.json`                                  | `config.toml`                             | primaryから共有link |
| workflow           | `agents`・`commands`・`hooks`・`rules`・`skills` | `hooks.json`・`prompts`・`skills`         | primaryから共有link |
| model layer        | 該当なし                                         | `heavy.config.toml`・`spark.config.toml`  | primaryから共有link |
| credential         | `.claude.json`内のOAuth state                    | `auth.json`                               | profileごとに分離   |
| conversation       | `projects`・`sessions`・`history.jsonl`          | `sessions`・`history.jsonl`・SQLite state | profileごとに分離   |
| local setting      | `settings.local.json`                            | `rules/default.rules`など                 | profileごとに分離   |
| plugin runtime     | `plugins`                                        | `plugins`                                 | profileごとに分離   |

共有linkは`clp`または`cxp`がprofile起動前に修復する。
profile側に同名のregular fileやdirectoryがある場合は自動置換せず停止する。

## Nix側のsource of truth

| 対象                                  | 管理file                                    |
| ------------------------------------- | ------------------------------------------- |
| Claude user settings・`clp`           | `nix/home-manager/programs/claude-code.nix` |
| Codex user config・model layer・`cxp` | `nix/home-manager/programs/codex.nix`       |
| `cl`・`cx`・Tab補完・`h`              | `nix/home-manager/programs/zsh.nix`         |
| shared skills                         | `agents/skills/`と`agent-skills.nix`        |

Codex credentialは`cli_auth_credentials_store = "file"`を固定する。
OS keychainを共有してprofile分離が崩れることを防ぐ。

## `h`との連携

`h`はNix管理abbrに加えてprofile managerと関連binaryを表示する。

```bash
h clp
h cxp
h clgpt
h clproxy
```

`abbr add`で追加したruntime abbreviationも実行時に読み込み、
`[Runtime abbreviations]`sectionへ展開先と一緒に表示する。

## 適用

```bash
dr
exec zsh
```

`dr`でprimary側の宣言設定を再生成する。
credential・conversation・plugin runtimeは変更しない。
