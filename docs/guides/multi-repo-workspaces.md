---
title: "複数repo workspaceの作成と共有"
created: 2026-09-06
type: guide
tags: [workspace, ghq, agents, indexion]
---

# 複数repo workspaceの作成と共有

## 方針

workspaceは同じproductに関係するrepo・目的・共通指示をまとめる親Git repo。新規workspaceは`repos/`へ子repoを直接cloneする。子repoは親のGit管理から除外し、それぞれの履歴を維持する。既存のghq checkoutを移動する必要はない。

基本操作に必要なのはGitとBun。Nixは共通ツールの版を揃える任意の入口。ghqは既存checkoutをリンクする方式を選ぶ場合だけ必要になる。ripgrep・indexion・agent CLIは対応する操作を使うときに用意する。

本人用の`ws`は`workspace`に展開するabbr。共有先では親repoに同梱した`./ws`を使い、個人dotfilesを必要としない。Nix宣言とHome Managerへの適用は別であり、未適用の間はdotfiles内で`bun agents/scripts/workspace.ts <command>`を使える。実productはまだ指定されていない。

workspaceの採用条件は次の通り。

- 一度の説明で構成repoと役割が伝わる
- 一度の検索で関係するrepoを横断できる
- repoごとのGit履歴・開発環境・詳細指示を維持できる
- MacとLinuxで同じ構成repoを復元できる

Herdrのworkspaceはterminal内のtab・paneを束ねる機能。ここで扱うworkspaceはfilesystemとproject contextの単位であり、[agent作業環境のツール方針](agent-workspace-tools.md)とは役割が異なる。Herdrのpaneをこのディレクトリで開く形で併用できる。

## 構成

```text
~/Workspaces/product/
  .git/                        # 親workspaceのGit履歴
  README.md                    # 共有先の初回操作
  AGENTS.md                    # productの目的とrepo関係
  CLAUDE.md                    # @AGENTS.md
  repos.json                   # repo URLと短いalias
  workspace.json               # checkout方式: local / ghq
  repos.lock.json              # 任意の全repo commit snapshot
  flake.nix / flake.lock       # 任意の共通ツール固定
  nix/indexion.nix             # 固定releaseとhashとKGF
  ws / scripts/workspace.ts   # チーム共通の操作入口
  .indexion/wiki/              # 共有する派生知識とpage metadata
  .indexion/digest/            # 各machineで再生成するindex
  .gitignore                   # /repos/を除外
  docs/                        # repoをまたぐ決定と引き継ぎ
  repos/
    web/.git/                  # 独立した子repo
    api/.git/                  # 独立した子repo
```

workspaceをprivate Git repoとして共有する。親repoにはURL一覧・共通指示・文書をcommitし、子repoの変更は各repoでcommitする。submodule化やmonorepo化は必要ない。

| 概念          | 管理するもの                           | 今回の扱い                               |
| ------------- | -------------------------------------- | ---------------------------------------- |
| ghq           | remote URLに対応するcheckoutの保管場所 | 維持                                     |
| workspace     | productの目的と関係するrepoの集合      | 追加する入口                             |
| Git worktree  | 同じrepoの別branchを扱うcheckout       | 同時編集が必要なtaskだけで使用           |
| Git submodule | 親repoが記録する子repoのcommit         | 構成全体のcommit固定が必要になったら検討 |
| monorepo      | 複数componentを一つのGit履歴で管理     | 今回の要件に不要                         |

## 導入手順

以下のURLは例示用。実際のrepoへ置き換える。

本人の初回作成は次の形になる。`init`は親directoryも作り、Gitを初期化する。既存directoryへの上書きは拒否する。

```bash
ws init ~/Workspaces/product
cd ~/Workspaces/product
./ws add https://github.com/example/product-web.git web
./ws add git@github.com:example/product-api.git api
./ws status
```

`add`が`repos.json`へ登録して不足repoをcloneする。aliasを省略するとrepo名を使い、名前の`.`を`-`へ置換する。clone失敗時も登録は残るので、Git認証や接続を直して`./ws sync`で再試行する。

生成される`repos.json`は次のようになる。手編集も可能。

```json
{
  "web": "https://github.com/example/product-web.git",
  "api": "git@github.com:example/product-api.git"
}
```

HTTPS・SSH・`host/owner/repo`を受け付ける。SSHの接続方式は保存される。token埋め込みURL・明示port付きURL・local pathはmanifestで扱わない。Gitのcredential helperまたはSSH認証を使う。

```bash
./ws add https://github.com/example/product-worker.git worker
./ws remove worker
```

`remove`は一覧から登録を外すだけでcheckoutとindexを削除しない。`add`も`remove`も自動commitやpushは行わない。`AGENTS.md`へproductの目的と各repoの役割を記入する。

```bash
./ws sync
./ws status
./ws rg -n 'PATTERN'
```

`sync`は不足checkoutを`repos/<alias>`へcloneする。既存checkoutではGit rootとoriginがmanifestに一致することを確認する。pull・branch切替・resetは行わず、別directoryや不一致リンクも上書きしない。

`init`はdotfilesのtemplate・CLI・indexion package定義をsnapshotとして複製する。生成物は個人のdotfilesや絶対パスに依存しない。template更新が既存workspaceへ無断適用されることはなく、更新時は差分をreviewして取り込む。

Nixを使う場合だけ次を実行する。Git flakeは未追跡fileを除外するため先にstageする。

```bash
git add flake.nix nix/indexion.nix
nix flake lock
git add flake.lock
nix develop
```

Codex・Claude Codeのbinaryと認証は各自で用意する。direnvを使う場合は`.envrc`を確認してから`direnv allow`する。

## 既存ghq checkoutを使う場合

初回sync前に`workspace.json`を`{"checkout":"ghq"}`へ変更する。この方式は不足repoを`ghq get`で取得して`repos/`へリンクする。実際の保存先は`ghq root`で解決し、このdotfilesでは`~/Develop`になる。

`workspace.json`のない旧workspaceもghq方式を維持する。方式変更による既存checkoutの移動や置換は行わない。別方式を試す場合は新しいworkspaceを作る。

## 共通指示

workspaceの`AGENTS.md`はrepoの説明を毎回繰り返す必要がなくなる程度に短くする。各repoのarchitecture全文やglobalルールを複製しない。

```markdown
# Product Workspace

## Purpose

Web clientとAPIをまたぐ変更を扱うworkspace。

## Repositories

| Path      | Role          | Read Before Editing                                |
| --------- | ------------- | -------------------------------------------------- |
| repos/web | Web client    | AGENTS.md / CLAUDE.md / repo指定のarchitecture文書 |
| repos/api | APIとcontract | AGENTS.md / CLAUDE.md / repo指定のarchitecture文書 |

## Workflow

- 編集対象repoの指示を読んでから変更する
- repo固有の指示はそのrepo内の変更に適用する
- 横断検索はrg -n 'PATTERN' repos/*/を使う
- Git操作はgit -C repos/<name>で対象repoを指定する
- API contract変更は定義側とWeb client側の両方を検証する
- buildとtestは対象repoの開発環境で実行する
- 同じcheckoutを複数agentから同時に変更する場合は所有fileを分ける
- 独立したbranch作業が必要な場合はtaskごとのworktreeを使う
- 引き継ぎはdocs/へ目的と変更repoと検証結果と次の作業を記録する
```

`CLAUDE.md`はこのrepoと同じ形式で共通指示をimportする。

```text
@AGENTS.md
```

workspaceから開始した場合も編集対象repoの指示を明示的に読む。子repoは独立したGit rootなので、そこから直接起動したsessionへ親workspaceの指示が自動継承されるとは考えない。[OpenAIのAGENTS.md仕様](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

ここに置く`AGENTS.md`・`CLAUDE.md`はproject共通指示。login用account profileではなく、credentialやnative sessionは各自のlocal stateに保持する。

## 検索と起動

workspaceの`repos/`はGit管理から除外する。この状態でworkspace全体を`rg -L PATTERN .`で検索するとrepoがignoreされる。リンク先を明示的な検索開始点として渡す。

```bash
rg -n 'PATTERN' repos/*/
rg --files repos/*/
git -C repos/web status --short
git -C repos/api status --short
```

明示したdirectoryのsymlinkはripgrepがたどり、各repo内部の`.gitignore`を維持できる。`rg -L PATTERN repos/`もfixtureでは動作したが、各repoを明示する形ならrepo内部の別symlinkまで再帰的にたどる指定は不要になる。`--no-ignore`を全体に指定する必要はない。通常の検索ではhidden fileを含めない。指示の確認などで必要なfileはパスを指定して読む。

Codex CLIはworkspaceをcwdにして各repoの実体を追加write directoryとして指定する。

通常は生成された入口で十分。追加のCLI引数も末尾へ渡せる。workspaceのprofileが未設定なら`CODEX_HOME`や`CLAUDE_CONFIG_DIR`を維持する。

workspaceごとにaccountを固定する場合は親directoryで次を実行する。`cxp list`・`clp list`の登録済みaccountをfzfで選択する。設定は親repoの`.git/config`だけに保存し共有fileには書き込まない。

```bash
ws profile codex
ws profile claude
ws profile
ws codex
ws claude
```

保存済みprofileは環境変数より優先する。起動は`cxp run`・`clp run`を経由し共有設定の同期とaccount照合を行う。profileが削除済みの場合やmanagerが見つからない場合は停止する。選択画面の`Esc`は設定を変更しない。`ws profile codex --clear`または`ws profile claude --clear`で解除すると従来の環境変数継承へ戻る。`default`の選択はprimary accountへの明示的な固定になる。

profile設定には親repoのGit初期化と対象の`cxp`・`clp`とfzfが必要。clone先では各自が設定する。古いworkspaceの`./ws`は作成時のCLIコピーなので自動更新されない。dotfiles適用後のグローバル`ws`をworkspace親directoryから使えば既存workspaceでも利用できる。新規生成したworkspaceでは`./ws profile`も使える。

```bash
./ws codex
./ws claude
```

これらは次の引数を組み立てる。

```bash
codex -C "$HOME/Workspaces/product" \
  --add-dir "$HOME/Workspaces/product/repos/web" \
  --add-dir "$HOME/Workspaces/product/repos/api"
```

Claude Codeは同じworkspaceから起動する。追加directory内のmemory読み込みを有効にする環境変数はこの起動だけに付ける。

```bash
cd "$HOME/Workspaces/product"
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude \
  --add-dir "$HOME/Workspaces/product/repos/web" \
  --add-dir "$HOME/Workspaces/product/repos/api"
```

Claude Codeの`--add-dir`は追加directoryへのtool accessを指定する。追加directoryの`CLAUDE.md`読み込みには別途上記環境変数が必要と公式文書に記載されている。[Claude Code memory](https://code.claude.com/docs/en/memory)・[permissions](https://code.claude.com/docs/en/permissions)

Codex Appや管理されたsessionでは追加write rootをsession側で指定する必要がある。symlinkは権限の付与にならない。追加repoの実体が既存sandbox外にある場合は起動元のworkspace設定を合わせる。

## 開発環境と同時作業

workspaceを開くだけで子repoの`.envrc`が全部読み込まれるわけではない。buildとtestは各repoの環境で実行する。

```bash
direnv exec repos/web bun test
direnv exec repos/api bun test
```

`bun test`は例であり、実際には各repoが指定する検証コマンドを使う。初回は各repoの`.envrc`を確認して`direnv allow <repo-path>`を行う。複数repoの`.envrc`をworkspace側でまとめて`source_env`すると環境変数が衝突し得る。さらに`source_env`は取り込み先の個別承認を確認しないため、環境はrepo単位で起動する。[direnv stdlib](https://direnv.net/man/direnv-stdlib.1.html)

symlinkで束ねる構成はcheckoutを共有する。同じrepoを別のworkspaceから開いてもbranchと未commit変更は共有される。別taskの同時進行ではそれぞれのrepoにworktreeを作り、task用workspaceからそのworktreeへリンクする。

```bash
git -C "$(ghq root)/github.com/example/product-web" worktree add \
  "$HOME/Worktrees/product/task-a/web" -b feature/task-a-web
```

worktreeを増やしただけでは複数repoの変更はatomicにならない。contractの互換性・merge順序・consumer側の検証結果はworkspaceのtask文書に残す。

ghq方式の`ws` CLIはmanifestとghq checkoutの実体一致を検査するため、任意のworktreeへの差し替えは扱わない。local方式ではworkspaceごとに独立cloneを持つ。worktreeの作成・割当を自動化する機能は未実装。

## 指定された3repoの評価

調査・実装日: 2026-09-07。indexionは実binaryでfixture検証済み。性能比較は未実施。

| 対象                                                                | 確認できた役割                                 | この環境での判断                                   |
| ------------------------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------- |
| [indexion](https://github.com/trkbt10/indexion)                     | 構造検索・類似検索・documentation解析・MCP     | 0.18.0と同梱KGFをhash固定してNix package化         |
| [indexion-skills](https://github.com/trkbt10/indexion-skills)       | indexion CLIを呼ぶClaude Code plugin           | 丸ごと導入せず検証済み操作の独立shared skillを追加 |
| [agent-std-workflow](https://github.com/trkbt10/agent-std-workflow) | source submoduleとworktreeと検証工程のtemplate | 考え方を部分採用                                   |

indexionはrepo配置の管理器ではない。workspaceが対象repoを決め、indexionは探索を補う。対応packageはmacOS ARM64とLinux x86_64。Linux ARM64のreleaseはないため今回の共通package対象外。MCPやHTTP serverの常時起動は追加せず、CLIを両agentから呼ぶ。[固定release](https://github.com/trkbt10/indexion/releases/tag/v0.18.0)

重要な実測差分として、0.18.0の`indexion search query path1 path2`はREADMEから想像する全fileの横断検索にはならなかった。既存digestがないと案内だけを表示してexit 0になる。workspaceの`search`はrepo別のdigest queryと共有wiki searchを順に実行する。全repoを一つの順位表や完全な依存graphへ統合する機能ではない。[固定版検索実装](https://github.com/trkbt10/indexion/blob/v0.18.0/cmd/indexion/search/cli.mbt)

indexion-skillsはbinaryとのversion整合を要求する。今回はこれを参考に独立した`indexion-workspace` skillを作り、実測したCLIへ誘導する。upstreamの長い手順とmutableなClaude pluginを重複導入しない。[indexion-skills README](https://github.com/trkbt10/indexion-skills#prerequisites)

agent-std-workflowはproductと工程の分離を提供する一方、基本形は単一の`source/` submodule。作業用worktreeから`source/main`へのcherry-pickを前提にするため、既存の複数ghq repoへ丸ごと適用すると工程が増える。今回は「目的とrepo構造の入口」「taskごとの分離」「consumer側での検証」「未確定調査と確定文書の区別」を採用する。固有のmodel選択やすべての修正へのPoC義務はglobalルールへ転写しない。[workflow README](https://github.com/trkbt10/agent-std-workflow)・[CLAUDE.md](https://github.com/trkbt10/agent-std-workflow/blob/main/CLAUDE.md)

## indexionとKnowledgeの使い方

まずrepo別のfunction indexを生成する。検索はlocal TF-IDFを明示し、外部embedding APIを使わない。

```bash
./ws index
./ws search 'refresh authentication token'
./ws query 'parse configuration'
./ws orient 'change authentication contract'
```

`search`は全repoのfunctionと登録済みwikiを検索し、`query`はfunctionだけを検索する。plain textの正確な検索は引き続き`./ws rg`を使う。TF-IDFの順位は語彙上の手掛かりであり、コードの意味理解やowner判定を保証しない。対応言語・検索漏れ・実projectでの速度は導入後にも確認する。

横断知識の正本はworkspace内の`./docs/knowledge/`へ置く。例えば認証contractのnoteを作成した後にwikiへ登録する。

```bash
indexion wiki pages add --id=authentication --title='Authentication contract' \
  --content=docs/knowledge/authentication.md \
  --sources=repos/web/src/auth.ts,repos/api/src/auth.ts --provenance=manual
./ws index
./ws search 'authentication contract'
```

source pathは例なので実在fileへ変更する。正本を更新したら派生pageも更新する。

```bash
indexion wiki pages update --id=authentication \
  --content=docs/knowledge/authentication.md
indexion wiki pages ingest --dry-run
./ws index
```

codeと文書のずれ候補は人が確認する。agentに推測だけで知識を確定させず、根拠repo・file・確認日・未確定事項を記録する。wikiの自動生成は採用判断の代わりにならない。

`.indexion/wiki/`のpage・metadata・navigationは共有し、digest/cache/vector DBは共有しない。indexには各自の絶対pathが入るためmachine上で再生成する。workspaceやcheckoutの場所を変えた場合も再生成する。

## チーム共有

workspaceそのものをprivate Git repoにする。共有するのは`repos.json`・`workspace.json`・共通指示・CLI snapshot・knowledge・task状態。Nixを使うteamは`flake.lock`も共有する。`repos/`・認証・`.env`・native session・生成indexはcommitしない。

参加者の初回操作は次の形になる。

```bash
git clone <workspace-repository-url> product-workspace
cd product-workspace
./ws sync
./ws status
./ws codex
```

参加者に必要なのはGitとBunおよび各repoへのGit認証。親repoに同梱したCLIで操作を揃え、各repoのruntime依存は各repoで管理する。個人dotfilesやNixの導入は必須ではない。

本人の環境など`workspace`がある場合は親と子のcloneをまとめられる。

```bash
ws clone https://github.com/example/product-workspace.git ~/Workspaces/product
cd ~/Workspaces/product
./ws status
```

`clone`は呼び出したCLIでsyncする。取得したrepoのscriptや`.envrc`を自動実行しない。途中で失敗した場合は残ったworkspaceで`./ws sync`を実行して再試行する。

repoを追加したら親の`repos.json`をcommitして共有する。他の参加者は親repoをpullして`./ws sync`するだけで追加分を取得できる。

構成repo名が同じでもcheckoutのcommitが同じとは限らない。再現確認や引き継ぎの節目にはclean checkoutからsnapshotを作る。

```bash
./ws snapshot
git add repos.lock.json
./ws verify
```

`verify`はcommitとclean状態を確認し、不一致でもcheckoutを変更しない。相手側は`./ws status`で差分を確認し、必要なら独立worktree上でsnapshotのcommitを使う。既存の作業branchを機械的にresetしない。

同じツール・指示・入力commitは共有できるが、agentのmodel・account権限・個人global instruction・samplingまで自動的に同一にはならない。teamの必須制約はworkspaceとrepoの指示へ置き、任意のglobal skillにしか存在しない手順を必須工程にしない。必要なskillをteam標準にする際はsource・version・license・依存をteam側でも固定する。

## 検証結果と残りの判断

再現用fixtureを次で実行する。temporary directory内に2repoを生成し、終了時にfixtureを削除する。実repoと通常のdirenv許可stateは変更しない。

```bash
bun agents/scripts/check-workspace.ts
INDEXION_BIN="$(command -v indexion)" bun test tests/workspace.test.ts
```

Nix packageからの生成と共有用`./ws`も検証する場合は次を使う。未追跡fileを含む開発中のtreeは`path:`で参照する。

```bash
workspace_package=$(nix build "path:$PWD#workspace" --no-link --print-out-paths)
indexion_package=$(nix build "path:$PWD#indexion" --no-link --print-out-paths)
WORKSPACE_BIN="$workspace_package/bin/workspace" \
  INDEXION_BIN="$indexion_package/bin/indexion" bun test tests/workspace.test.ts
```

Lint workflowでも両packageをbuildしてこのtestを実行する。Macでは15件が成功し、生成fileの編集権限とworkspace外からの共有入口の起動も確認した。GitHub ActionsでのLinux実行は未確認。

2026-09-06のMac上で確認済み。

- workspaceからの通常のrecursive検索ではsymlink配下が探索されない
- repoを明示した検索では2repo両方が見つかる
- workspaceの`/repos/` ignoreとrepo内の`vendor/` ignoreが両立する
- symlink経由でも各repoのGit rootが独立している
- repoごとの指示fileを明示的に読める
- direnvはrepoごとの許可が必要になる
- workspaceでは子repoの環境が自動合成されない

追加fixtureではMac実binaryによる2repoのdigest生成・function検索・wiki検索・orientの出力、syncの冪等性、既存path保護、manifest検証、revision snapshot、template生成を確認した。実product規模の負荷とLinux実行は未検証。

agentが指示を自動注入する挙動はfixtureでは検証していない。ネストしたCodex sandboxは以前の試験では外側のsandboxにより拒否された。起動引数とwrite rootの指定は用意したが、実productを選んだ最初のsessionで権限と指示読み込みを確認する。
