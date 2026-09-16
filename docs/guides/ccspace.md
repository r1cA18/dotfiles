---
title: "ccspaceによるClaude Code・Codexのaccount切り替え"
created: 2026-09-16
type: guide
tags: [ccspace, claude-code, codex, accounts]
---

# ccspaceによるClaude Code・Codexのaccount切り替え

## 方針

Claude CodeとCodexのaccount切り替えは外部tool `ccspace`(`Omakase-Robotics-Org/ccspace`、private repo)を使う。
自作の`clp`/`cxp`(旧`agent-profile-manager`)は置き換えられ、`archive/agent-profile-manager/`へ退避済み。

ccspaceはNix packageではない。`~/.local/share/ccspace`へgit cloneし、tool自身の`install.sh`が
`~/.local/bin/ccspace`とshell補完を生成する。TypeScriptをbunで直接実行する構成で、
Claude CodeやCodex本体と同じくnative installer方式に近い。

ccspaceは`account`(emailベースのCLAUDE_CONFIG_DIR/CODEX_HOME切り替え)ではなく、
`space`(config directory、例: `~/.claude-work`)と`launcher`(それを起動するshim、例: `cc-work`)という
概念を使う。Claude用launcherは`cc-<name>`、Codex用launcherは`cx-<name>`という命名規約で、
どちらも`~/.local/bin`に実行可能fileとして生成される。email紐付けspace(`~/.claude--you@example.com`
のような命名)はlogin実体との整合を`ccspace doctor`がpledgeとして検証する。

## 導入と更新

初回導入はhome-manager activationが自動で行う。

```bash
dr
```

`nix/home-manager/programs/ccspace.nix`のactivationが`~/.local/share/ccspace`へclone
(`~/.local/state/ccspace/install.log`にログ)し、続けて`install.sh`を実行する。
既にcloneとinstallが済んでいれば何もしない。

更新は`update-ccspace`を使う(`update-all`にも組み込み済み)。

```bash
update-ccspace
update-all
```

`update-ccspace`は`git -C ~/.local/share/ccspace pull --ff-only`のあと`install.sh`を再実行する。

## 起動方法

`ccspace add`でlauncherを作成すると、`~/.local/bin`に実行可能fileが生成される。
以後はそのlauncherをそのまま起動commandとして使う。

```bash
ccspace add cc-work
cc-work
```

## よく使うcommand

```bash
ccspace list             # 登録済みlauncher一覧
ccspace add cc-work       # launcher + spaceを作成
ccspace doctor            # 整合性チェック(read-only)
ccspace usage             # quota確認
ccspace launch            # quota最大のaccountで起動
```

以下はNixが自動化しない手動step。導入直後や環境を変えたときに個別に実行する。

```bash
ccspace statusline --all  # status line導入
ccspace service install   # login item化
```

## `ws profile`との連携

複数repo workspace(`ws`、[multi-repo-workspaces.md](multi-repo-workspaces.md)参照)では、
workspaceごとに使うlauncherを固定できる。

```bash
ws profile codex
ws profile claude
ws profile
ws codex
ws claude
```

`ws profile <agent>`はfzfで`~/.local/share/ccspace/spaces.json`に登録済みのlauncher
(`cx-*`または`cc-*`)を選択し、親repoの`.git/config`へ`workspace.codexLauncher`/
`workspace.claudeLauncher`として保存する。共有fileには書き込まない。
`ws profile <agent> --clear`で解除すると環境変数継承へ戻る。
`ws codex`/`ws claude`は保存済みlauncherがあればそれを、なければ通常の`codex`/`claude`を起動する。

launcherが未登録の場合は`ccspace add`を先に実行する必要がある。

## Nix側のsource of truth

| 対象                       | 管理file                                |
| -------------------------- | --------------------------------------- |
| ccspace導入・更新          | `nix/home-manager/programs/ccspace.nix` |
| `ws profile`のlauncher解決 | `agents/scripts/workspace.ts`           |
| `h`のccspace表示           | `nix/home-manager/programs/zsh.nix`     |

ccspace本体のcode・launcher定義・spaces.jsonの形式はdotfiles外(`ccspace` repo自体)が正になる。
dotfiles側はcloneと更新経路、および`ws profile`からの連携のみを管理する。

## `h`との連携

`h`は`ccspace`のcommand例も表示する。

```bash
h ccspace
```

## 回帰検証

ccspaceはdotfiles外のtoolのため、`DOTFILES_TEST_NIX=1`のNix統合testには含まれない
(旧`clp`/`cxp`は`tests/agent-profiles.test.ts`でNix build込みの検証をしていたが、
archiveと同時にtest suiteからも外れた。詳細は[testing.md](testing.md)を参照)。
`ccspace doctor`がread-onlyの整合性チェックを提供する。
