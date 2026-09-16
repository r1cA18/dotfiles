---
title: "dotfilesの回帰テスト"
created: 2026-09-07
type: guide
tags: [testing, ci]
---

# dotfilesの回帰テスト

## 普段の検証

```bash
bash scripts/test.sh
```

既定の`unit`はNixを呼び出さずに文書の参照先とBunの回帰テストを実行する。Bun・Git・ghq・ripgrep・jq・Python 3・Zsh・fzf・標準Unix toolsが必要。開始時に依存commandを確認し不足していれば終了する。対話UIの選択結果はfixtureで供給するため実際のterminal操作は不要。

`tests/`・`agents/hooks/`・`claude/hooks/`・`agents/skills/`配下の`*.test.ts`は自動収集する。新しい回帰テストを追加したときにCIのfile一覧を手で更新する必要はない。Nix生成物を使うテストは`DOTFILES_TEST_NIX=1`で有効にし通常のunit実行ではskipする。

## Nix生成物を含む検証

```bash
bash scripts/test.sh all
```

`all`はunitの後に`integration`を実行する。workspaceとindexionのNix packageをbuildし実indexionによる検索と配布用workspaceの操作を確認する。生成されたClaude・Gemini・Codexのglobal instructionも実fileで比較し、共通ruleの順序とCodex専用routingの境界を確認する。integrationの対象はApple Silicon macOSとx86_64 Linux。

依存ツールが揃っていない環境ではCIと同じくこのrepoの`flake.lock`から供給できる。

```bash
nix shell --no-write-lock-file --inputs-from . \
  nixpkgs#bash nixpkgs#bun nixpkgs#coreutils nixpkgs#findutils \
  nixpkgs#gawk nixpkgs#gnugrep nixpkgs#gnused nixpkgs#git \
  nixpkgs#ghq nixpkgs#ripgrep nixpkgs#jq nixpkgs#python3 \
  nixpkgs#zsh nixpkgs#fzf \
  --command bash scripts/test.sh all
```

生成物だけを再確認するときは`bash scripts/test.sh integration`を使う。旧`clp`/`cxp`をNix buildして検証していた`tests/agent-profiles.test.ts`は、`ccspace`への置き換えに伴い`archive/agent-profile-manager/`へ退避し、このunit/integration testsuiteの対象からも外れた。

## 検証範囲

| 検査              | 対象                                                                 |
| ----------------- | -------------------------------------------------------------------- |
| workspace         | clone・同期・manifest検証・checkout保護・共有entrypoint・検索        |
| configuration     | Home Manager生成fileのshared instructionとCodex専用routingの配布境界 |
| hook              | structured advisory・Git index検査・Knowledge link・Stop再入防止     |
| handoff           | 会話の抽出・privileged content除外・JSON不正入力・HTML escape        |
| shellとskill      | 個別の`tests/`内fixtureによる回帰検証                                |
| `nix flake check` | formatter・deadnix・statix・Linux homelabのshellとAnsible            |
| Linux build CI    | Home Manager activation packageのbuild                               |

テストは一時directoryとmock CLIを使う。普段のaccountでloginせずagentを起動せずsystemやHome Managerの設定も適用しない。Nix検証はstoreへのbuildと必要な依存downloadを行う。

CIの`regression`jobはLinuxで共通入口を実行しformatterなどの失敗とは独立して結果を出す。macOSのsystem build・agentからのhook発火・通知音・実terminalでの対話表示は別途確認が必要。テストの成功を全OSの実機適用成功とは扱わない。

新しいテストは壊れたときの利用者への影響を基準に選ぶ。文言の完全一致や実装を写しただけのassertionを増やさず入力境界・変更保持・権限やaccountの分離を優先する。
