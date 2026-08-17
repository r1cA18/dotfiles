# dotfiles 管理ルール

## 基本方針

1. **宣言的に管理** - user設定はHome Manager、macOS systemはnix-darwin、Ubuntu systemはAnsibleで管理
2. **1ファイル1責務** - 設定は機能ごとに分割
3. **OS分岐は最小限** - 共通化できるものは共通化
4. **ドキュメントを残す** - 変更時はdocs/も更新

## ファイル編集ルール

### パッケージ追加

| 種類                      | 編集ファイル                                               | 例            |
| ------------------------- | ---------------------------------------------------------- | ------------- |
| CLI（Nix）                | `nix/home-manager/programs/packages.nix`の`commonPackages` | ripgrep, fd   |
| CLI（custom npm package） | `nix/pkgs/<name>/` + `packages.nix`                        | agent-browser |
| GUI（macOS）              | `nix/darwin/configuration.nix`の`homebrew.casks`           | discord       |
| macOS専用                 | `packages.nix`の`darwinPackages`                           | texliveFull   |
| Linux専用                 | `packages.nix`の`linuxPackages`                            | Nerd Font     |
| Ubuntu system / GUI       | `homelab/ansible/playbook.yml`                             | Docker        |

### エイリアス追加

**必ず `cmd + desc` 形式で定義**（ヘルプ自動生成のため）

```nix
# zsh.nix
myAliases = {
  alias_name = {cmd = "actual-command"; desc = "説明";};
};
```

カテゴリ選択：

- `generalAliases` - 汎用
- `nixCommonAliases` - Nix共通
- `nixDarwinAliases` / `nixLinuxAliases` - Nix OS別
- `dirDarwinAliases` / `dirLinuxAliases` - ディレクトリ
- `claudeAliases` - Claude Code

新カテゴリ作成時：

1. 定義を追加
2. `helpSections`にカテゴリ追加
3. `abbrDefs` に入れるかどうかを決める

### Skills追加

1. `agents/skills/<name>/SKILL.md`を追加する
2. `nix/home-manager/programs/agent-skills.nix`の`skills.enable`へnameを追加する
3. 外部CLIが必要なら`nixpkgs`または`nix/pkgs/`でpackage化する
4. `dr`でClaudeとCodexへ同期する

runtime installerをactivationへ直接埋め込まない。再現可能なCLIはNix packageとして管理する。

## OS分岐パターン

```nix
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in {
  # 条件分岐
  something = if isDarwin then "mac" else "linux";

  # リストマージ
  packages = common ++ (if isDarwin then darwin else linux);
}
```

## コミットルール

commitは変更理由が分かるConventional Commit形式にする。実際に共同作業したauthor以外の
`Co-Authored-By`は追加しない。

### type

- `feat` - 新機能
- `fix` - バグ修正
- `docs` - ドキュメント
- `refactor` - リファクタリング
- `chore` - その他

## 動作確認

変更後は必ず：

```bash
# 共通format
nix fmt

# macOS
nh darwin build ~/dotfiles -H RMB

# Ubuntu Home Managerとprovisioning checkはGitHub ActionsのLinux jobで検証

# 新しいターミナルで確認
h  # エイリアス確認
```

## トラブルシューティング

### activation script がエラー

1. activation に依存していないか確認
2. custom package 化できるものは `nix/pkgs/` に移す

### エイリアスが反映されない

1. 新しいターミナルを開く
2. `source ~/.zshrc`

### パッケージが見つからない

```bash
nix search nixpkgs <package-name>
```
