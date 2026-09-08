---
title: "開発環境の棚卸しと改善順序"
created: 2026-09-06
type: research
tags: [dotfiles, agents, architecture, environment-review]
---

# 開発環境の棚卸しと改善順序

## 判断

今のNix・ghq・共有agent資産という基礎構造は維持する。
不足しているのはprojectをまたぐ作業の入口と、設定・配布・実際の動作を区別する管理だ。
まず発見と引き継ぎを整え、重複するworkflowの選択とOS差分の観測を改善する。

この調査は2026-09-05に中断した作業を引き継いだもの。
現在のworking treeには別作業の未commit変更もあるため、既存差分を保持して確認した。
modelの変更やsystemへの一括適用は行っていない。

## 役割を分ける

| 単位              | 担当                                   | 正本                                  |
| ----------------- | -------------------------------------- | ------------------------------------- |
| machine           | OS・GUI・daemon・login環境             | NixとAnsible                          |
| account profile   | 認証・session・plugin runtime          | 各製品のlocal state                   |
| repo              | code・Git履歴・devShell・repo固有指示  | ghq管理下の各repo                     |
| product workspace | 目的・repo構成・共通contract・横断作業 | workspaceのmetadataと文書             |
| task              | 変更範囲・判断・検証結果・次の作業     | task文書と必要なworktree              |
| skill             | 繰り返す特定workflow                   | 共有skillまたは版を固定した外部source |
| plugin            | 製品固有のtool・接続・配布単位         | 宣言設定と製品側のruntime             |

workspaceはrepoの保管やGit履歴を置き換えない。
同じproductのrepoをまとめて読める入口を作る。
task用worktreeは複数の独立作業を同じcheckoutへ重ねたくないときに使う。

## 棚卸し結果

| 領域           | 主な発見                                                     | 詳細                                                   |
| -------------- | ------------------------------------------------------------ | ------------------------------------------------------ |
| workspace      | ghq rootは`~/Develop`。repo一覧と共通指示の入口がない        | [構成案と検証](../guides/multi-repo-workspaces.md)     |
| skills/plugins | YAML不正・監査基準の逆転・workflow重複・profile別cache差     | [資産台帳](agent-assets-audit-2026-09.md)              |
| Mac/Linux      | 共通CLIは整備済み。GUIは設定だけの配布がある                 | [差分と管理境界](platform-parity-2026-09.md)           |
| 日本語         | owner会話とUIの文体を分ける規約を補強する必要があった        | [表記ガイド](../guides/japanese-writing.md)            |
| 引き継ぎ       | account分離は機能しているが別profileの履歴探索に手間がかかる | [再開と移送の比較](../guides/agent-session-handoff.md) |

## 今回の改善

| 変更                       | 状態                                              | 検証                                   |
| -------------------------- | ------------------------------------------------- | -------------------------------------- |
| 共有日本語ルールと用例     | 前回の6行追加と新規guideを引き継いで確認          | 配布元と外部資料の適合性を確認         |
| skill-auditorの評価基準    | 強いtrigger文言の加点を廃止                       | YAML検証と参照間の整合確認             |
| agent-browserとbaseline-ui | descriptionのYAML構文を修正                       | 修正前のparse失敗と修正後の成功を確認  |
| session-handoff            | 共有skillと抽出filterを追加・Nix配布宣言へ登録    | 4 testsと実ログ抽出                    |
| 複数repo workspace         | 構成と起動手順を作成                              | 使い捨て2repoで検索・Git・direnvを確認 |
| Linuxの診断                | Codex参照先をnative CLIへ修正・primary homeを明示 | shell構文確認                          |
| Ollamaの説明               | Linuxへ導入済みと読めるコメントを訂正             | Ansibleの実宣言と照合                  |

変更はsourceに保存済み。`dr`やLinuxへのremote適用は未実施。
新skillは直接パスを指定すれば今すぐ読める。自動discoverには各hostへの反映と新規sessionが必要。

## 添付記事の取り入れ方

元sessionの添付から2本の文章を回収した。
1本目のskill descriptionの短縮と適用範囲の明確化は、現在のskill-creatorの方針とも整合する。
常時指示を増やす代わりに今回の監査基準へ反映した。

2本目には能力や自動化を強く一般化した主張が含まれていた。
能力向上を全作業の成功保証とせず、今回の実測と完了条件で判断する。
価格・model名・実験的configの例をそのままglobal設定へ転写する変更は行っていない。

公式の[Astra guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)も
指示への感度・文体・委譲・検証量の調整を挙げている。
今回の分担は独立した3領域の調査に限定し、統合判断は親agentで行った。
検証はログ抽出とworkspace境界など壊れると引き継ぎを誤る箇所へ集中した。
別accountや別providerへの切替をmodel能力だけで完全に解決できるとは扱わない。

## 次の改善順序

1. 実productのrepoを1組選びworkspaceを作成して横断変更を1件完了
2. skill-builderの旧監査基準とbrowser操作workflowの製品依存を整理
3. design・document系skillの該当依頼と非該当依頼で選択を評価
4. Linuxの接続回復後に最新宣言の適用状態とCodexの2系統のversionを確認
5. LinuxのGUI用途が必要ならGhostty・Zedの本体をAnsibleへ追加
6. 履歴のnative移送が繰り返し必要なら`cct`を隔離homeで評価

全skillの一括削除や全GUIの横並び導入は今回の棚卸し結果からは必要と判断していない。
個別の採否は資産台帳とOS差分表に記録し、今回未検証の動作を導入済みと扱わない。

## 確認の限界

Darwinのsystem derivation評価は成功した。
LinuxのactivationPackage評価は既存video-editing skillの生成過程でLinux用ffmpeg等のbuildが必要となり、
Mac上のoffline評価ではplatform mismatchで止まった。
構文エラーと断定できる失敗ではないがLinuxの全構成を検証済みとは扱えない。
Linux実機への再接続もtimeoutしたため、Linux側でのbuildと稼働確認が残る。

通常のGit flakeは新しい未追跡fileを取り込まないため、今回の評価では`path:`でworking treeを指定した。
Nixのfull build・activationとagentの指示自動注入の検証は未実施。
workspace fixtureの成功は実repoの権限やbuildの成功を保証しない。
