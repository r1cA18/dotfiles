# エイリアス自動ヘルプシステム

## 概要

エイリアスを`cmd + desc`形式で定義し、`h` / `hv`コマンドでカテゴリ別ヘルプを自動生成する仕組み。

## 背景・課題

### 元々の状態

```nix
commonAliases = {
  ll = "eza -la";
  dr = "nh darwin switch ~/dotfiles -H RMB";
};
```

### 問題点

- エイリアスが増えると覚えられない
- 何があるか確認する方法がない
- ヘルプを別管理すると同期がズレる

## 解決策

### 方針

Nix管理aliasは1箇所で管理し、自動生成する。

```nix
# Before: エイリアスだけ
ll = "ls -la";

# After: cmd + desc のセット
ll = { cmd = "eza -la --group-directories-first --icons=auto"; desc = "List files with eza"; };
```

### 実装

**zsh.nix:**

```nix
# カテゴリ別にエイリアス定義
generalAliases = {
  ll = {cmd = "eza -la"; desc = "List files with eza";};
  nv = {cmd = "nvim"; desc = "Open Neovim";};
  dot = {cmd = "cd ~/dotfiles"; desc = "Go to dotfiles";};
};

nixCommonAliases = {
  du = {cmd = "nix flake update --flake ~/dotfiles"; desc = "Update flake";};
};

nixDarwinAliases = {
  dr = {cmd = "nh darwin switch ~/dotfiles -H ${hostname}"; desc = "Apply Darwin config";};
};

nixLinuxAliases = {
  dr = {cmd = "nh home switch ~/dotfiles -c ${username}@linux"; desc = "Apply Home Manager config";};
};

claudeAliases = {
  clc = {cmd = "cl --continue"; desc = "Continue last Claude session";};
  clr = {cmd = "cl --resume"; desc = "Resume Claude session from picker";};
  cld = {cmd = "cl --dangerously-skip-permissions"; desc = "Start Claude without prompts";};
};

# ヘルプ生成関数
mkAliases = defs: lib.mapAttrs (name: v: v.cmd) defs;

mkCategoryHelp = category: defs: let
  lines = lib.mapAttrsToList (name: v: "  ${name} - ${v.desc}") defs;
in "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

mkCategoryHelpVerbose = category: defs: let
  lines = lib.mapAttrsToList (name: v: "  ${name} = ${v.cmd}") defs;
in "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

# `h` / `hv` は shell function で生成文字列を出す
```

### 使い方

```bash
# 簡潔なヘルプ（説明付き）
$ h
[General]
  ll - List files with eza
  nv - Open Neovim
  dot - Go to dotfiles

[Nix]
  dr - Apply Darwin config
  du - Update flake
  ...

[Claude Code]
  clc - Continue last Claude session
  clr - Resume Claude session from picker
  ...

# 詳細ヘルプ（コマンド内容）
$ hv
[General]
  ll = eza -la
  nv = nvim
  dot = cd ~/dotfiles
  ...
```

## カテゴリ構成

| カテゴリ       | 内容                                      |
| -------------- | ----------------------------------------- |
| General        | 汎用（ll, nv, dot, ..）                   |
| Nix            | Nix関連（dr, du, ds, dg, nd, db, dp）     |
| Directory      | ディレクトリ移動（dev, drive, downloads） |
| Claude Code    | Claude Code関連（clc, clr, cld, cls）     |
| Codex          | Codex関連（cx, cxc, cxr, cxrev）          |
| Agent Commands | `clp`・`cxp`・`clgpt`・`clproxy`          |

`Agent Commands`はPATH上のcanonical binaryを表示する専用sectionになる。
shell aliasやabbrには変換しないため、実体のcommandをshadowしない。

## Runtime abbreviation

`abbr add`で追加したruntime abbreviationはNix evaluation時には存在しない。
`h`と`hv`は実行時に`abbr list-abbreviations`と`abbr expand`を読み、
Nix管理abbrとの重複を除いて次のsectionへ追加する。

```text
[Runtime abbreviations]
foo = some command
```

runtime abbreviationにはdescriptionがないため、`h`と`hv`の両方で展開先を表示する。

## エイリアス追加方法

1. 適切なカテゴリの定義に追加：

   ```nix
   generalAliases = {
     # 既存のもの...
     new = {cmd = "some-command"; desc = "Description";};
   };
   ```

2. 新カテゴリを作る場合：
   - 定義を追加
   - `helpSections`にカテゴリ追加

## まとめ

| 項目           | 内容                                                   |
| -------------- | ------------------------------------------------------ |
| 管理ファイル   | `nix/home-manager/programs/zsh.nix`                    |
| ヘルプコマンド | `h`（説明）, `hv`（コマンド）, `h <query>`（絞り込み） |
| 追加方法       | `{cmd, desc}`形式で定義に追加                          |
| 自動生成       | Nix管理分は静的生成しruntime abbrは実行時に追加        |
