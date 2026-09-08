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
clp doctor
clp archive user@example.com

cxp list
cxp add user@example.com
cxp login user@example.com
cxp status user@example.com
cxp path user@example.com
cxp doctor
cxp archive user@example.com
```

`run`・`login`・`status`・`path`でemailを省略するとfzf pickerが開く。

`run`は追加profileのdirectory名と実際のlogin emailを起動前に照合する。
一致しない場合はaccountを誤使用しないよう起動を停止する。
`doctor`はidentity・metadata・shared link・permissionの不整合を読み取り専用で検査する。
`archive`はdefault以外のprofileを削除せずrecoverable trashへ移動する。

`help`・`list`・`complete`・`path`・`doctor`・`archive`はnative CLIが未導入でも使える。
`add`・`login`・`status`・`run`は`~/.local/bin`のnative CLIを必要とする。
CLIがない場合は`update-codex`または`update-claude-code`で導入してから再実行する。
`login default`は現在の`CODEX_HOME`や`CLAUDE_CONFIG_DIR`を引き継がずprimaryへloginする。

## 保存場所

```text
Claude primary       ~/.claude + ~/.claude.json
Claude追加profile    ${XDG_STATE_HOME:-~/.local/state}/claude-code/profiles/<email>
Claude archive       ${XDG_STATE_HOME:-~/.local/state}/claude-code/trash/<email>-<timestamp>

Codex primary        ~/.codex
Codex追加profile     ${XDG_STATE_HOME:-~/.local/state}/codex/profiles/<email>
Codex archive        ${XDG_STATE_HOME:-~/.local/state}/codex/trash/<email>-<timestamp>
```

追加accountはemailをdirectory名にしてstate directoryへ追加する。
`add`中にloginやidentity確認が失敗したprofileもtrashへ退避する。

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

Linuxで`clp`や`cxp`自体が見つからない場合は、native CLIの不足と区別する。
`command -v clp cxp`と`ls ~/.nix-profile/bin/clp ~/.nix-profile/bin/cxp`で確認し、
Home Managerへprofile managerを含む設定が適用済みか調べる。
`~/.nix-profile/bin`に存在する場合は新しいlogin shellでPATHを確認する。
存在しない場合はLinux側checkoutの差分を確認してから`dr`を適用する。
Macでの変更だけではLinuxのNix生成commandは更新されない。

## 回帰検証

```bash
DOTFILES_TEST_NIX=1 bun test tests/agent-profiles.test.ts
```

testは実行hostに対応するHome Manager設定から`clp`と`cxp`をNixでbuildする。
生成packageを直接実行するためBashとGNU toolsもNixの依存関係から供給される。
native CLIだけをmockに置き換え、一時directory内の架空accountで管理操作・作成・起動・
default再loginの分離を検証する。実accountのcredentialは使わない。
対象hostはApple Silicon Macとx86_64 Linuxとなる。

初期testはLinux向けshellをMacで実行し、Linux依存binaryが未取得の間だけMacのPATHへ
fallbackして成功していた。LinuxのcoreutilsがNix storeへ取得された後に実行形式の不一致が
現れたため、host用packageのbuildと直接実行へ強化した。今回の実行検証はMacで行い、
Linuxについては宣言評価のみとなる。Linux実機の不具合解消は別途確認が必要となる。
