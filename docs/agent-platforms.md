# Agent Platform 運用ガイド

`dotfiles` では `Codex` を主軸にしつつ、`Claude Code` も併用できる構成を目指す。
そのために、共有すべきものと製品固有のものを分離して管理する。

## Source Of Truth

| 項目                         | Source of truth                                   | 補足                                                                  |
| ---------------------------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| グローバル instruction       | `agents/INSTRUCTIONS.md` + `agents/rules/`        | Nixで結合してClaude・Codex・Geminiへ配布する                          |
| project-specific instruction | `AGENTS.md`とこのドキュメント                     | `CLAUDE.md`は`AGENTS.md`をimport                                      |
| reusable skills              | `agents/skills/`                                  | `~/.claude/skills` と `~/.codex/skills` に同期                        |
| shared hook implementations  | `agents/hooks/`                                   | 製品ごとのhook登録から呼び出す                                        |
| Claude hooks                 | `claude/hooks/`                                   | Claude 専用                                                           |
| Claude commands              | `claude/commands/`                                | 可能なら `agents/skills/` へ昇格                                      |
| Codex prompt wrappers        | `codex/prompts/`                                  | deprecated なので reusable workflow は skill が正本                   |
| Claude agents                | `claude/agents/`                                  | Markdown frontmatter 形式                                             |
| Codex agents                 | `.codex/agents/`                                  | TOML 形式                                                             |
| Codex user config            | `nix/home-manager/programs/codex.nix`             | `~/.codex/config.toml` を writable copy 生成                          |
| Claude settings              | `nix/home-manager/programs/claude-code.nix`       | `programs.claude-code.settings` から `~/.claude/settings.json` を生成 |
| GPT backend wrapper          | `nix/home-manager/programs/claude-code-proxy.nix` | `clgpt`・`clproxy`・user serviceを生成                                |
| Gemini global instruction    | `nix/home-manager/programs/antigravity.nix`       | `~/.gemini/GEMINI.md`を生成                                           |
| Claude user MCP seed         | `claude/mcp-servers.json`                         | `~/.claude.json` へ merge する前提                                    |
| Claude Code binary           | native install                                    | Home Managerが未導入時にbootstrapしてchannelを管理                    |

## 共有できるもの

- `agents/INSTRUCTIONS.md`
- `agents/rules/`
- `agents/hooks/` の製品非依存script
- `agents/skills/`
- project docs
- MCP のうち plugin 非依存で宣言的に書ける server 定義

## 共有できないもの

- 製品固有のhook登録とschema
- `Claude Code` plugins / marketplaces
- `Claude Code` custom commands のうち UI 依存のもの
- `Codex` custom prompts の UI 呼び出し部分
- `Codex` custom agents の TOML 実装
- runtime state を含む `~/.claude.json`
- Antigravityのprovider・credential・session state

Claude account profileは`clp`で管理する。Codex account profileは`cxp`で管理する。
どちらもemailから解決し、公開dotfilesにはemailを保存しない。
共有設定だけをprimary profileからlinkし、credential・session・plugin cacheは分離する。
詳細は[Agent account profile管理](guides/agent-profiles.md)を参照。

## 現在の方針

### 1. Skills First

再利用したい workflow はまず `agents/skills/` に置く。
`Claude` の command や plugin skill でしか使えない状態は避ける。
Codex の custom prompt は deprecated なので、`codex/prompts/` は skill を呼び出す薄い wrapper に留める。

### 2. Tool-specific enforcement stays local

- 自動ブロック
- status line
- notification
- plugin marketplace

こういうものは共有化せず、各ツール側に残す。

### 3. Runtime state is not declarative

以下は dotfiles の完全管理対象にしない。

- `~/.claude.json`
- plugin cache
- transcripts
- session state

必要な宣言的設定だけ repo 内に切り出して、runtime state へ merge する。

## Plugin の扱い

Claude plugin は runtime install され、実体は `~/.claude/plugins/` に置かれる。
dotfiles では以下だけを管理する。

- `enabledPlugins`
- `extraKnownMarketplaces`

plugin 本体に入っている useful skill は、継続利用したいなら `agents/skills/` に移植して共通資産化する。

Codex plugin も runtime cache は `~/.codex/plugins/cache/` に置かれる。
dotfiles では `nix/home-manager/programs/codex.nix` で以下を管理する。

- `marketplaces`
- `[plugins."<name>@<marketplace>"].enabled`

GitHub 等から入れる個人用 Codex plugin は、できるだけ flake input と local marketplace として固定する。
`claude-code-advisor@claude-plugin-codex` は Codex から local Claude Code を呼ぶ global bridge として管理する。
現行の `codex plugin` は project-local `.codex/config.toml` ではなく `~/.codex/config.toml` を更新する。
そのため、Codex plugin は project ごとに切り替えず global 管理する。
runtime cache 自体は生成物なので dotfiles には入れない。

## GPT backend版Claude Code

純正`claude`はAnthropic接続のまま維持する。`clgpt`だけがprocess-local環境変数で
`claude-code-proxy`へ接続する。Proxyのuser serviceはon-demandで起動しlogin時には
常駐させない。

`antigravity-for-claude-code`はClaude Code pluginとしてofficial `agy`へdelegateする。
`clgpt`から使う場合はGPTがmain conductorになりAntigravity/Geminiがsub-agentになる。

Antigravityは既存Google account sessionを使う。Gemini API keyとVertex credentialは
dotfilesへ追加しない。`~/.gemini/antigravity-cli/settings.json`も変更しない。

詳細は[GPT backend版Claude Code](guides/claude-code-gpt.md)を参照。

## MCP の扱い

### Codex

`Codex` の MCP は `nix/home-manager/programs/codex.nix` で declarative に管理する。
必要になったら user config 側へ明示的に追加する。

### Claude Code

`Claude Code` の user-level MCP は runtime file の `~/.claude.json` に入るため、
dotfiles では `claude/mcp-servers.json` を source of truth にして、必要な server 定義だけ merge する。
この merge は `nix/home-manager/programs/claude-code.nix` の activation でprimary profileにだけ実行する。
追加profileへの同期と宣言から削除したserverの除去は未対応なので、runtime file全体を管理済みとは扱わない。

## CLI 依存 skill の扱い

`agent-browser` のように外部 CLI を前提にする skill は、
dotfiles 側で runtime も含めて宣言的に入れる。

- パッケージ定義: `nix/pkgs/`
- user environment への追加: `nix/home-manager/programs/packages.nix`
- skill の有効化: `nix/home-manager/programs/agent-skills.nix`

現時点でこの方針で管理している代表例:

- `agent-browser`
- `codex`
- `gemini`

`skills` CLI 自体は upstream の配布形態が不安定なので、常設 package にはせず `bunx skills` を使う。
