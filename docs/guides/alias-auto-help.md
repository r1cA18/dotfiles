# エイリアス自動ヘルプシステム

## 概要

エイリアスを`cmd + desc`形式で定義し、`h`コマンドでカテゴリ別ヘルプを自動生成する仕組み。

## 背景・課題

### 元々の状態

```nix
commonAliases = {
  ll = "ls -la";
  dr = "sudo darwin-rebuild switch ...";
};
```

### 問題点

- エイリアスが増えると覚えられない
- 何があるか確認する方法がない
- ヘルプを別管理すると同期がズレる

## 解決策

### 方針

**1箇所で管理、自動生成**

```nix
# Before: エイリアスだけ
ll = "ls -la";

# After: cmd + desc のセット
ll = { cmd = "ls -la"; desc = "List all files"; };
```

### 実装

**zsh.nix:**

```nix
# カテゴリ別にエイリアス定義
generalAliases = {
  ll = {cmd = "ls -la"; desc = "List all files";};
  nv = {cmd = "nvim"; desc = "Open Neovim";};
  dot = {cmd = "cd ~/dotfiles"; desc = "Go to dotfiles";};
};

nixCommonAliases = {
  dr = {cmd = "sudo darwin-rebuild switch --flake ~/dotfiles/nix#RMB"; desc = "Rebuild nix config";};
  du = {cmd = "nix flake update --flake ~/dotfiles/nix"; desc = "Update flake";};
};

claudeAliases = {
  cc = {cmd = "claude"; desc = "Start Claude Code";};
  ccc = {cmd = "claude --continue"; desc = "Continue last session";};
  ccd = {cmd = "claude --dangerously-skip-permissions"; desc = "Skip all permissions";};
};

# ヘルプ生成関数
mkAliases = defs: lib.mapAttrs (name: v: v.cmd) defs;

mkCategoryHelp = category: defs: let
  lines = lib.mapAttrsToList (name: v: "  ${name} - ${v.desc}") defs;
in "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

mkCategoryHelpVerbose = category: defs: let
  lines = lib.mapAttrsToList (name: v: "  ${name} = ${v.cmd}") defs;
in "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

# 最終的なエイリアス
finalAliases = mkAliases allDefinitions // {
  h = "echo '${helpText}'";
  hv = "echo '${helpTextVerbose}'";
};
```

### 使い方

```bash
# 簡潔なヘルプ（説明付き）
$ h
=== General ===
  ll - List all files
  nv - Open Neovim
  dot - Go to dotfiles

=== Nix ===
  dr - Rebuild nix config
  du - Update flake
  ...

=== Claude Code ===
  cc - Start Claude Code
  ccc - Continue last session
  ...

# 詳細ヘルプ（コマンド内容）
$ hv
=== General ===
  ll = ls -la
  nv = nvim
  dot = cd ~/dotfiles
  ...
```

## カテゴリ構成

| カテゴリ | 内容 |
|---------|------|
| General | 汎用（ll, nv, dot, ..） |
| Nix | Nix関連（dr, du, ds, dg, nd, db, dp） |
| Directory | ディレクトリ移動（dev, drive, downloads） |
| Claude Code | Claude Code関連（cc, ccc, ccr, ccd, ccu） |
| Help | ヘルプ自身（h, hv） |

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
   - `allDefinitions`にマージ
   - `helpText`/`helpTextVerbose`にカテゴリ追加

## まとめ

| 項目 | 内容 |
|------|------|
| 管理ファイル | `nix/home-manager/programs/zsh.nix` |
| ヘルプコマンド | `h`（簡潔）, `hv`（詳細） |
| 追加方法 | `{cmd, desc}`形式で定義に追加 |
| 自動生成 | Nix関数で`h`, `hv`の中身を生成 |
