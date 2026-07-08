# Neovim 運用ガイド

ryoppippi 式のハイブリッド構成。バイナリ類は Nix、プラグインは lazy.nvim が管理し、
設定は out-of-store symlink なので編集は即反映される。

## アーキテクチャ

役割分担は次の 3 層。

- Nix (`nix/home-manager/programs/neovim.nix`) が nvim 本体 / LSP / formatter / treesitter grammar を供給する
- lazy.nvim がプラグインを管理し `nvim/lazy-lock.json` の commit にピン留めする
- `nvim/` は `~/.config/nvim` への out-of-store symlink なので、設定編集に `dr` は不要

Nix が供給するもの:

- nvim 本体 (`programs.neovim`)
- LSP / formatter バイナリ (`extraPackages`): `vtsls` `bash-language-server` `lua-language-server` `nixd` `biome` `taplo` `marksman` `yaml-language-server` `vscode-langservers-extracted` ほか
- treesitter grammar 一式 (`nvim-treesitter.withAllGrammars`)。`TREESITTER_GRAMMARS` env で wrap し `init.lua` が runtimepath に追加する

Mason は無効化してある (`core.lua`)。バイナリは全て Nix 側から PATH で供給されるため、
プラグイン側では入れない。

## どこに何があるか

| 対象                       | 場所                                             |
| -------------------------- | ------------------------------------------------ |
| nvim 本体 / LSP / grammar  | `nix/home-manager/programs/neovim.nix`           |
| エントリポイント           | `nvim/init.lua`                                  |
| lazy.nvim 設定             | `nvim/lua/config/lazy.lua`                       |
| プラグイン spec            | `nvim/lua/plugins/*.lua`                         |
| lockfile (source of truth) | `nvim/lazy-lock.json`                            |
| 基本設定                   | `nvim/lua/config/{options,keymaps,autocmds}.lua` |

## 日常フロー

### プラグインを追加する

1. `nvim/lua/plugins/` に spec ファイルを追加する
2. nvim を開き `:Lazy install` を実行する。`nvim/lazy-lock.json` に pin が書き込まれる
3. `nvim/lazy-lock.json` と spec ファイルを commit する

### プラグインを更新する

1. `:Lazy update` を実行する
2. 動作確認する
3. 変わった `nvim/lazy-lock.json` を commit する

### 別マシン / 新規マシン

`git pull` してから `dr` を実行する。`dr` の activation hook (`nvimLazyRestore`) が
`nvim --headless "+Lazy! restore" +qa` を実行し、committed lockfile 通りにプラグインを揃える。
nvim か git が無い環境では hook は何もしない。

## 主なプラグイン

| プラグイン             | 用途                              | keymap / ft          |
| ---------------------- | --------------------------------- | -------------------- |
| `oil.nvim`             | バッファとしてファイル操作        | `-` で親ディレクトリ |
| `sidekick.nvim`        | Claude Code / Codex CLI 連携      | `<leader>aa/ac/ax`   |
| `render-markdown.nvim` | Markdown のバッファ内レンダリング | markdown ft のみ     |
| `obsidian.nvim` (fork) | Obsidian vault 連携               | `~/vault` 検出時のみ |

`obsidian.nvim` の spec は `~/vault` が無いマシンでは空 spec に畳まれるので、
vault が同期されていない環境でも nvim はエラーにならない。

## TypeScript

`nvim/lua/plugins/typescript.lua` で LazyVim の `lang.typescript` extra を import している。
LSP は vtsls (LazyVim の現行デフォルト)。バイナリは `pkgs.vtsls` から供給する。

## トラブルシューティング

### lockfile のコンフリクト

`nvim/lazy-lock.json` は JSON なので行単位でコンフリクトする。片方を採用したら
`:Lazy restore` で checkout を lock に合わせ直し、再度 commit する。

### プラグインを 1 個だけ巻き戻す

`git log -p nvim/lazy-lock.json` で以前の commit を確認し、`nvim/lazy-lock.json` の
該当行だけ元の commit に書き換えて `:Lazy restore` する。

### noice.nvim の cmdline UI (既知の問題)

`nvim/lua/plugins/core.lua` で noice の cmdline UI を無効化している
(`opts.cmdline.enabled = false`)。`:` 入力時に treesitter ベースのハイライトが
壊れるため。原因は nvim-treesitter (main ブランチ rewrite) の runtime と
Nix 供給の grammar セットの噛み合わせと見られる。安全に解消できる確証が無いため
回避策を残している。再有効化を試すなら sandbox (分離した `XDG_*`) で
`opts.cmdline.enabled` を戻して `:` 入力を確認すること。

### grammar が見つからない

Nix 供給の grammar は `TREESITTER_GRAMMARS` env 経由で `init.lua` が runtimepath に
追加する。効いていない場合は `:echo $TREESITTER_GRAMMARS` で env を確認し、
nvim が Nix wrap 版か (`which nvim` が `/etc/profiles/...` 配下か) を確認する。

## 補足: 日本語検索 (任意)

migemo / kensaku 系のローマ字インクリメンタル検索は入れていない。必要なら
`kensaku.nvim` 等を追加する余地はあるが、現状は素の検索で運用している。
