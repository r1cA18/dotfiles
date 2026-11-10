---
title: homelabでのworkspace生成とセッション継続の現状
created: 2026-10-05
type: research
tags: [harness, workspace, remote-development, homelab]
---

# 目的

移動中のMacを実行hostにせずhomelabでコードとagent sessionを保持する。Macやphoneは入力・閲覧・承認と再接続のclientにする。新しい有料cloudの購入やprovisionは今回の範囲に含めない。

# 実装済みと未実装

| 項目 | 現状 |
| --- | --- |
| repoを必要分だけclone | workspace CLIのrepos.jsonとsyncで可能 |
| hostをまたいだ同じ配置 | portable modeのrepos/aliasなら同じ相対構造を再現可能 |
| ghq配置 | host側のghq rootを使用。絶対pathの一致は不要 |
| repo revision確認 | snapshot/verifyがある。dirty checkoutを上書きしない |
| host内のaccount選択 | workspaceのlocal Git configでlauncherを選択 |
| remote workspace自動生成 | host指定で配置を生成する統合CLI/APIは未実装 |
| accountのhost間同期 | local Orcaからccspaceへの投影のみ。credential転送は未実装 |
| homelab Orca server | Nix packageとsystemd設定が未統合差分にある |
| Task/Attempt復旧 | CoreのCLIで実装・ローカル検証済み |
| native session再接続 | Orca側のruntime機能に依存。実機縦断は未検証 |
| Mac停止中の継続 | homelabで実行する構成なら可能な見込み。現在の運用で確認済みとは言えない |

Coreのenvironment registryはhost登録と退役と観測を扱う。登録だけでrepoやprocessを作らない。CoreのWorkspaceはpolicy境界でありdotfilesのファイル配置workspaceとは別。両者を明示的な配置参照で結ぶ。

# 最小実装案

1. 配置manifestに必要なrepo URLとaliasとrevisionを宣言する。秘密値とaccount tokenは含めない
2. host側の許可root下でmanifestを検証して既存workspace CLIのportable syncを呼ぶ
3. origin mismatchとdirty checkoutを拒否して既存作業を保持する。生成と削除は別操作にする
4. そのhostのlogin済みaccountとgroup policyを確認する。Macのcredentialを自動複製しない
5. idempotentなeffect IDでOrca sessionを作成してhost/worktree/session IDをCore Attemptへ保存する
6. client切断とworker停止を区別する。MacのsleepをTask失敗にしない
7. reconnectは保存済みsession IDを使う。unknown startは再起動せずreconcileを要求する

CLIとAPIは共通serviceを使いCLI操作から先に一本通す。上記は提案する責務であり現在のコマンドとして提示しない。新しいcommand名は実装Issueで確定する。

# 受入テスト

- 2 repoだけを指定してhomelabに同じ相対構造を生成
- 再送してもworkspaceやsessionが二重に生成されない
- dirtyな既存repoと別originを上書きしない
- Macをsleepさせてもhost上の作業が継続
- phoneとMacから同じsessionへ再接続
- TaskとAttemptから実際のhost/sessionを追跡可能
- credentialの未配置時は明示的な不足を返して別accountへfallbackしない
- 実行hostのrestart時はunknownを明示して勝手に再実行しない

# 留意点

headless OrcaのLinux packageは1.4.215で固定されている。ローカルMacで観察した版と同一ではない。mobile pairingとaccount pathとsession再接続をLinux実機で確認する必要がある。ccspace-sync-orcaの現行pathはmacOS用でありLinuxのOrca profile配置にはそのまま対応しない。Nix設定の保存・build・実機適用・接続成功は別の完了条件として記録する。

# 参照

- dotfiles: agents/scripts/workspace.tsとtemplates/workspace/README.md
- dotfiles: nix/home-manager/hosts/homelab.nixとnix/pkgs/orca-ide/default.nix
- dotfiles: nix/home-manager/programs/ccspace.nix
- [Core Router #22](https://github.com/r1cA18/harness-core/issues/22)
- [Core環境registry #36](https://github.com/r1cA18/harness-core/issues/36)

# 次の作業

homelab設定を独立した環境管理PRとしてreviewする。その後既存hostへのread-only接続確認と小さなrepoでの縦断テストを行う。自動化を完成と呼ぶのはMac停止中の継続と同一session再接続の両方が通ってからとする。
