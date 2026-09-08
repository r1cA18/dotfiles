---
title: "環境見直しの実装進捗"
created: 2026-09-07
type: session-log
tags: [agents, workspace, skills, hooks, nix]
---

# 環境見直しの実装進捗

## 目的

基礎skillの選定と共有配布、Linux profile不具合、hook負荷と停止loop、docsへのtask状態保存、indexion付きteam workspaceを扱う。既存の未commit変更は保持する。

## 確認済みの節目

- profile管理のCLI不在時の全面停止とdefault loginのaccount環境継承をfixture再現して修正
- hookの誤検知とStop loopを再現して修正
- 共有engineering ruleに意味のある節目でのtask状態更新を追加
- skill候補を公式優先で本文とlicenseまで確認して追加対象を限定
- indexion 0.18.0の公式assetとKGFを固定してNix packageを追加
- workspace CLIと独立共有templateを追加
- Macの実indexionで2repo function検索とwiki検索とorientを確認
- indexion/workspace両Nix packageのMac buildとmacOS全体のderivation評価を確認
- 独立templateのMac/Linux dev shell評価とMacでの実際のdev shell起動を確認
- workspace reviewでmanifest不一致とsymlink出力先とClaude引数境界を修正して回帰testを追加

## 判断

ghqのcheckoutを移動しない。workspaceでrepo構成・目的・知識・共通toolsを共有し、認証とcheckoutとindexは各自で持つ。indexionのREADMEと0.18.0実挙動に差があり、複数pathをそのままsearchへ渡す方式は採用せずrepo別digest queryとwiki searchを集約する。

記事のモデル固有の速度・消費量の主張は測定結果として転写しない。適用条件と段階的参照は採用し、必要な専門知識・権限境界・変更に見合う検証は残す。全skillを一括削減したとは扱わない。

## 未完了・未検証

- Linux実機へのSSHがtimeoutするため報告症状との一致とremote適用
- 試行productと構成repoの指定
- 実product規模での検索精度と負荷
- team別machineからの初回onboarding
- Home Managerへの全体適用と新sessionでのskill/hook読み込み

## 次の作業

対象productが決まったらworkspaceを作成して最初の横断taskを通す。Linuxの実際のerrorと接続を確認し、適用後にprofile切替を再検証する。

新規fileをGitへ追加する前の通常の`dr`ではGit flakeがfileを除外する。今回の評価とpackage実行は`path:` flake参照を使用した。通常運用へ反映する際は変更対象をreviewしてGit管理へ追加する。既存の未commit変更も含む全体適用について確認を出しており、未回答の間は`dr`を実行しない。

## 最終検証

- workspace 8件とprofile 8件とhook 20件とhandoff 4件の計40 testsが成功
- profile testはhost用Nix packageをbuildして直接実行
- indexion/workspaceのMac package buildが成功
- macOS system全体のderivation評価が成功
- shared skill bundleの43件でYAMLとname一意性を確認
- 独立workspaceのMac/Linux dev shell評価とMac実行が成功
- docs path lintと`git diff --check`が成功

途中でLinux packageをMacから呼ぶtest harnessの欠陥が判明した。依存binaryが未取得のときだけhost PATHへfallbackしていたため、最終検証ではhost packageを実行する方式へ変更した。この成功をLinux実機での動作確認とは扱わない。

## 追加記事の採否

- 採用: `AGENTS.md`のarchitecture参照を変更領域に対応させて重複指定を削除
- 採用: 必要なテストを残しつつ変更の影響に見合う検証へ限定
- 採用: skillの適用範囲と段階的参照を重視
- 不採用: 出典だけで速度・費用・token削減率を実測扱いにすること
- 既定化を保留: 全accountの実験的context管理

手元のnative Codex 0.153.4では`context_management`はunder developmentで既定false。process限定のconfig overrideを付けた`features list`ではtrueになることを確認した。永続configは変更していない。

```bash
codex -c 'features.context_management.experimental_mode=true'
```

この形なら新taskだけで試せる。CLIが設定を受理することとbackendで期待どおり保持・検索できることは別。公式説明ではChatGPT Plus/Pro/Pro Liteの認証が必要であり、全accountの資格や実際の長期taskでは未検証。別taskの会話を全部自動検索する設定ではない。[公式設定仕様](https://learn.chatgpt.com/docs/config-file/config-reference)・[context管理](https://learn.chatgpt.com/docs/models?surface=cli#experimental-context-management)

## workspace操作の簡略化（同日追記）

追加依頼に合わせて新規workspaceの既定をlocal checkoutへ変更した。既存ghq checkoutは維持し、`workspace.json`のない旧workspaceは従来の方式で動く。

- `init`で親directoryと親Git repoを初期化
- `add <URL> [alias]`でmanifest登録とcloneを実行
- `clone <URL> <dir>`で共有親repoと構成repoを取得
- `remove <alias>`で登録だけを外しcheckoutとindexは保持
- 基本操作はGitとBunだけで実行可能
- Nixは共通ツール固定の任意入口として維持
- 本人用`ws`をabbrと自動helpへ追加
- `nx`と`dp`を互換名として表示し明示名を案内
- account profile補完に`doctor`と`archive`を追加

GitとBunだけをPATHに置いたfixtureでclone・add・sync・snapshot・verifyを確認した。既存pathの保護・origin不一致・重複URL・無効URLの拒否も確認した。Macでworkspace Nix packageのbuildとZsh生成評価が成功した。引き継ぎ後のpost-reviewと追加検証も完了した。

### 引き継ぎ後のreviewと検証

Nix packageからの`init`で生成fileにNix storeの読み取り専用modeが残り、`add`によるmanifest更新を妨げる問題を再現した。新規生成物だけにowner書き込み権限を付け、`ws`の実行権限も維持した。

共有用`./ws`のdirectory解決をBash組み込みへ変更した。Git・Bun・BashだけをPATHに置き、workspace外から絶対pathで起動しても追加とsnapshot検証が動くことを確認した。

- workspaceの15 testsが成功（実indexionのghq/local検索とNix packageからの生成を含む）
- 修正後のworkspace Nix packageがMacでbuild成功
- CIと同じNix依存指定によるMacでの15 testsが成功
- Zsh評価で`ws`のalias・abbr・help登録と`dr`・`dot-rollback`の値を確認
- 既存Lint workflowへworkspaceのpackage buildと回帰testsを追加

GitHub ActionsでのLinux実行と実productのonboardingは未検証。Home Managerへの全体適用も未実施。

構造棚卸しの残りはprofile・hook・handoffのBun回帰testsのCI接続、登録解除済みhookの保管方針、skill-builderとskill-auditorの基準差。大規模なdirectory移動は必要と判断していない。

## 単独実行への変更と追加整理

所有者の追加指示によりCodexのサブエージェント利用を停止した。`codex/rules/orchestration.md`に単独実行を定義し、Luna・Solへの委譲方針を置き換えた。共有ルールより優先し他CLI経由の迂回も禁止する。このrepoの`AGENTS.md`にも明示した。Claude・Geminiの共有instructionにはCodex専用ルールを含めない。

`h`のfzf選択式helpと`hp`の絞り込み・詳細表示、workspace移動の`wsg`を追加した。helpは選択したcommandを実行しない。既存の`hv`・`devg`も維持する。

登録解除済みの`auto-format.sh`と`test-reminder.sh`を削除した。Git履歴から復元可能。skillの作成・監査基準とbrowser依存の修正は[資産監査](agent-assets-audit-2026-09.md)へ追記した。

回帰テストの入口を`bash scripts/test.sh all`へ統一しLinux CIへ接続した。Macでunitとintegrationが成功し、integrationは39 tests・0 fail。Nix生成packageとinstruction配布を検証し、mockによるskill helper検証も追加した。実agent起動やaccount loginや設定適用は行っていない。

Home Managerの全体適用とGitHub Actions上の実行と実productのonboardingは未実施。

## 2026-09-08の適用確認

上記の未適用という記録は当時の状態。実装commit `8791604`をMacへ`dr`相当の`nh darwin switch`で適用し成功した。

- SSH全体の`Bash(ssh *)`をClaudeのallowへ移動しdenyから削除
- SSH秘密鍵fileへの直接Read/Edit制限は維持
- Codexの`features.multi_agent = false`と単独実行instructionの配布を確認
- 新しいlogin shellで`workspace`のPATHと`ws`展開と`h`・`hp`・`hv`・`wsg`・`devg`の定義を確認
- Mac system buildとformatting・pre-commit checksが成功
- `bash scripts/test.sh all`はunit 48 pass・18 skip・0 failとintegration 40 pass・0 fail
- fixture tokenの生成方式変更後にprofile 14 testsを再実行して成功
- staged差分のgitleaks検査で検出なし

unitのNix依存skipはintegrationで検証する。suite間で重複があるため件数を合算しない。全skill資産の網羅検証と実際のNix生成help catalogの対話E2Eは未整備。Linux実機とGitHub Actions上の結果と実product onboardingも未確認。SSH許可の確認は設定上の確認でありJetsonへの接続試験ではない。

## 2026-09-08の追加ルールとマージ準備

手入力が必要なcommandを本人のclipboardへコピーする共有ルールを追加した。Macは`pbcopy`を使いLinuxは利用可能なdesktop sessionとtoolに応じて`wl-copy`・`xclip`・`xsel`を使う。commandは展開せず文字列として渡し成功後だけコピー済みと伝える。headless SSHなど本人のclipboardに届かない場合は未コピーと明示する。

Codexは単独実行方針を維持し短周期の状態確認を避ける待機ルールを追加した。完了通知と対応する待機toolを優先し待機時間は残り時間の見積もりとtool上限と応答性の制約に従う。記事のmulti-agent待機設定は無効化中の機能用なので追加しない。token削減量は実測していない。

- 追加変更後のMacでunit 48 pass・18 skip・0 fail
- integration 40 pass・0 fail
- Nix生成instructionで共有clipboardルールとCodex専用ルールの配布境界を確認
- branch差分の`git diff --check`が成功

Macの`nix flake check`も成功した。PR #12の初回CIではLinux版indexionのOpenSSL動的読み込み失敗とgitleaks actionへのtoken渡し忘れを確認した。Linuxのruntime依存へOpenSSLを追加しsecret-scanに読み取り権限と自動tokenを渡す。PRコメントは無効にする。

次は修正後のLinux CIを確認してmainへマージする。今回の追加instructionの実環境への適用とLinux実機でのclipboard操作は未実施。

## 関連文書

- [workspace運用](../guides/multi-repo-workspaces.md)
- [profile操作](../guides/agent-profiles.md)
- [hook運用](../guides/agent-hooks.md)
- [skill管理](../guides/skills.md)
