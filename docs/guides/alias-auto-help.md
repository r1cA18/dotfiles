# エイリアス自動ヘルプシステム

## 概要

エイリアスと操作コマンドを`cmd + desc`形式で定義し、一覧・検索picker・詳細previewを同じ定義から生成する。操作例が必要な項目には`help`を追加する。

## 普段の使い方

| 操作                      | 動作                                        |
| ------------------------- | ------------------------------------------- |
| `h`                       | 対話terminalでfzfのhelp pickerを開く        |
| `hp workspace`            | workspaceを検索した状態でhelp pickerを開く  |
| `h workspace`             | 説明一覧を正規表現で絞り込んで出力する      |
| `hv '^ws ='`              | `ws`の展開先を出力する                      |
| `h \| less`               | 対話pickerを開かず説明一覧を出力する        |
| `wsg`                     | `~/Workspaces`からworkspaceを選んで移動する |
| `wsg /path/to/workspaces` | 指定した場所からworkspaceを選んで移動する   |

help pickerでは名前・カテゴリ・説明を検索できる。右側のpreviewに実際のコマンドと登録済みの操作例を表示する。`Shift-Up`・`Shift-Down`でpreviewをscrollし、`Enter`で選択項目の詳細をterminalへ出力する。選んだコマンドや操作例は実行しない。`Esc`で閉じる。

`h`は引数がある場合やstdin/stdoutがterminalでない場合に従来の一覧出力を使う。fzfがない場合も一覧へ戻る。`hp`と`wsg`はfzfが必要になる。

`wsg`は`repos.json`のあるdirectoryを探す。子repoが入る`repos/`・`.git/`・`node_modules/`は探索しない。選択後に現在のshellで`cd`するだけで、cloneやscript実行は行わない。候補なしや`Esc`では現在のdirectoryを維持する。workspace作成は`ws init ~/Workspaces/product`を使う。

## 定義と実装

正本は`nix/home-manager/programs/zsh.nix`。shell functionは`nix/home-manager/programs/zsh-tools.zsh`に分離し、Nixから読み込む。両fileの変更を通常のshellへ反映するにはHome Managerの適用と新しいshellが必要になる。

```nix
ws = {
  cmd = "workspace";
  desc = "Manage workspaces";
  help = "作成: ws init ~/Workspaces/product\n登録: ./ws add <repo-URL> web";
};
```

`help`がない項目も説明と展開先をpreviewする。`ccspace`・`clgpt`・`clproxy`などの実コマンドと`h`・`hp`・`hv`・`devg`・`wsg`のshell functionはhelpへ掲載し、同名aliasを追加しない。

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

### 定義の例

**zsh.nix:**

```nix
# カテゴリ別にエイリアス定義
generalAliases = {
  ll = {cmd = "eza -la"; desc = "List files with eza";};
  nv = {cmd = "nvim"; desc = "Open Neovim";};
  dot = {cmd = "cd ~/dotfiles"; desc = "Go to dotfiles";};
};

nixCommonAliases = {
  update-all = {
    cmd = "nix flake update --flake ~/dotfiles && update-github-apps && update-claude-code && update-codex && update-antigravity";
    desc = "Update flake + GitHub apps + Claude Code + Codex + Antigravity";
  };
};

nixDarwinAliases = {
  dr = {cmd = "nh darwin switch ~/dotfiles -H ${hostname}"; desc = "Apply Darwin config";};
};

nixLinuxAliases = {
  dr = {cmd = "nh home switch ~/dotfiles -c ${username}@linux"; desc = "Apply Home Manager config";};
};

claudeAliases = {
  clc = {cmd = "claude --continue"; desc = "Continue last Claude session";};
  clr = {cmd = "claude --resume"; desc = "Resume Claude session from picker";};
  cld = {cmd = "claude --dangerously-skip-permissions"; desc = "Start Claude without prompts";};
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
# 簡潔なヘルプ（説明付きの一覧出力）
$ h | cat
[General]
  ll - List files with eza
  nv - Open Neovim
  dot - Go to dotfiles

[Nix]
  dr - Apply Darwin config
  update-all - Update flake + GitHub apps + Claude Code + Codex + Antigravity
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

| カテゴリ       | 内容                                          |
| -------------- | --------------------------------------------- |
| General        | 汎用（ll, nv, dot, ..）                       |
| Nix            | Nix関連（dr, update-all, ds, dg, nd, db, dp） |
| Directory      | ディレクトリ移動（dev, drive, downloads）     |
| Claude Code    | Claude Code関連（clc, clr, cld, cls）         |
| Codex          | Codex関連（cx, cxc, cxr, cxrev）              |
| Workspace      | `ws`から`workspace`への短縮入口               |
| Agent Commands | `ccspace`・`clgpt`・`clproxy`                 |
| Help           | `h`・`hp`・`hv`                               |

`Agent Commands`はPATH上のcanonical binaryを表示する専用sectionになる。
shell aliasやabbrには変換しないため、実体のcommandをshadowしない。

## 命名と互換性

`ws`は`workspace`へ展開する。作成は`ws init ~/Workspaces/product`で、共有workspace内の操作は同梱の`./ws`を使う。詳しくは[workspace運用](multi-repo-workspaces.md)を参照。

- dotfilesへの移動は`dot`を推奨し同じ動作の`nx`は互換名として維持
- Macのrollbackは`dot-rollback`を推奨
- Linuxの世代一覧は`dot-generations`を推奨
- 旧`dp`は互換名として維持するがMacとLinuxで操作が異なる
- `dr`はdotfiles適用に予約しoh-my-zshのDocker aliasより優先する
- Docker containerの起動には`docker run`を使用
- `cl`・`cx`系の既存prefixとsession操作の短縮名は維持

`clp`・`cxp`は廃止し`ccspace`へ置き換えた。補完はccspace自身の`install.sh`が生成する。

## Runtime abbreviation

`abbr add`で追加したruntime abbreviationはNix evaluation時には存在しない。
`h`と`hv`は実行時に`abbr list-abbreviations`と`abbr expand`を読み、
Nix管理abbrとの重複を除いて次のsectionへ追加する。

```text
[Runtime abbreviations]
foo = some command
```

runtime abbreviationにはdescriptionがないため、`h`と`hv`の両方で展開先を表示する。
help pickerにも同じruntime abbreviationを掲載し、展開先を文字列としてpreviewする。

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

## 検証

```bash
zsh -n nix/home-manager/programs/zsh-tools.zsh
bun test tests/shell-tools.test.ts
```

testsは一覧出力・runtime abbreviationの重複除外・fzf選択・workspace探索と移動・取消を確認する。実PTYのtestではhelp previewを描画し、`Esc`で終了することと操作例が実行されないことを確認する。PTY作成やpreview subprocessを禁止するsandboxではそのtestを実行できない。

## 管理項目

| 項目           | 内容                                                    |
| -------------- | ------------------------------------------------------- |
| 管理ファイル   | `nix/home-manager/programs/zsh.nix`                     |
| ヘルプコマンド | `h`・`hp`（picker）と`hv`（展開先一覧）                 |
| 追加方法       | `{cmd, desc}`形式で定義に追加し必要に応じて`help`を付加 |
| 自動生成       | Nix管理分は静的生成しruntime abbrは実行時に追加         |
