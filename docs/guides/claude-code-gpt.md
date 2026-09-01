# GPT backend版Claude Code

`claude`はAnthropicへ直接接続する。`clgpt`だけがlocalhostの
`claude-code-proxy`を経由してChatGPT/Codexへ接続する。

```text
claude  ──────────────────────────────> Anthropic

clgpt  -> 127.0.0.1:18765 -> Codex -> ChatGPT subscription
  └── antigravity plugin -> agy -> existing Google account session
```

## 初回設定

Nix configuration適用後にCodex OAuthを1回だけ実行する。

```bash
clproxy auth login
clproxy status
clproxy models
```

認証は`claude-code-proxy`が管理する。macOSではKeychainへ保存される。
tokenとcredentialはdotfilesで管理しない。

Antigravityは既存のofficial `agy` CLIとGoogle account sessionを使う。
Gemini API keyとVertex credentialは設定しない。
`~/.gemini/antigravity-cli/settings.json`を含むprovider・session・conversation stateは
Home Managerの管理対象外にする。

Claude Code起動後に以下を1回実行してplugin health checkを完了する。

```text
/antigravity:setup
```

## コマンド

| コマンド | 用途                                      |
| -------- | ----------------------------------------- |
| `claude` | 純正Claude Codeのprimary profile          |
| `cl`     | 純正Claude Codeのaccount picker           |
| `clgpt`  | GPT backend版Claude Codeのprimary profile |
| `clg`    | GPT backend版Claude Codeのaccount picker  |
| `clgc`   | GPT backendの直近sessionをcontinue        |
| `clgr`   | GPT backendのsession picker               |
| `clgd`   | GPT backendをpermission promptなしで起動  |

## Proxy管理

`clgpt`は起動時にCodex認証とProxy healthを検査する。Proxyが停止中なら
on-demand user serviceを起動する。login時には自動起動しない。

```bash
clproxy start
clproxy stop
clproxy status
clproxy foreground
clproxy logs
clproxy models
clproxy auth status
```

`clproxy foreground`はmonitor TUIを表示する。background serviceを停止してから使う。
listenerはdefaultの`127.0.0.1:18765`から変更しない。Proxyにはclient認証がないため
non-loopback bindは禁止する。

default modelはupstream v0.1.35のcatalogに合わせて以下を使う。

```text
main: gpt-5.6-sol[1m]
fast: gpt-5.6-luna[1m]
```

model ID変更時は`clproxy models`を正とする。一時変更は以下で行う。

```bash
CLGPT_MODEL='gpt-5.6-terra[1m]' clgpt
CLGPT_FAST_MODEL='gpt-5.6-luna[1m]' clgpt
```

## Claude profile管理

profileは`clp`で管理する。primaryを含む全profileをemailから解決できる。

```bash
clp list
clp add user@example.com
clp run user@example.com
clp gpt user@example.com
clp status user@example.com
```

`clp run`と`clp gpt`はemail省略時にfzf pickerを開く。
`cl user@example.com`と`clg user@example.com`で直接指定もできる。
Tab補完は登録済みemailを`clp complete`から動的に取得する。

新規profileのruntime stateは`$XDG_STATE_HOME/claude-code/profiles/<email>`に置く。
未設定時は`~/.local/state`を使う。
emailはlocal pathとClaude自身のaccount metadataにだけ残り、公開dotfilesには保存しない。

各profileは以下だけをprimary profileと共有する。

- settings
- global instruction
- agents
- commands
- hooks
- rules
- skills

credentials・sessions・history・local settings・plugin cacheなどのruntime stateは共有しない。

Codexを含む共通構造は[Agent account profile管理](agent-profiles.md)を参照。

## Antigravityの境界

Claude Code側では`antigravity-for-claude-code` marketplaceとpluginの有効化だけを
宣言管理する。plugin cacheとjob stateはruntime stateとして管理しない。

`~/.gemini/GEMINI.md`にはClaude Code・Codexと同じshared instructionを配布する。
`.gemini`全体はsymlinkせず既存のGoogle loginとAntigravity stateを保持する。

Googleのthird-party softwareに関するFAQは変更される可能性がある。official `agy`を
pluginから呼ぶ構成でもaccount riskが明示的に免除されるとは限らないため
利用時点のtermsとFAQは別途確認する。
