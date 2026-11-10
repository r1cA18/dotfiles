---
title: Harness関連差分のGitHub管理
created: 2026-10-05
type: research
tags: [harness, github, environment]
---

# 目的と分離

小さなdesktop/installer修正をmainへ反映する。ハーネスと検証と環境管理は別feature branchのDraft PRへまとめる。既にmainへmergeされたmodel profileとaccount identityは重複させない。作業中の元checkoutは変更を保持する。

| 区分 | 変更 |
| --- | --- |
| main | Aerospace shortcutとDarwin font配置とAntigravity/Claude/Devin installer修正 |
| feature/harness-environment-management | Nix flake構成整理とlock更新とhomelab/Orca runtimeとaccount/workspace設定と進捗・調査記録 |
| 既存main | model-profile compilerとimmutable account identityとOrca SQLite authority維持 |
| 調査のみ | Olympus UI改修とTask/Attempt接続とremote workspace/sessionの不足 |

# 確認結果

- main用の回帰テスト62 passと4 skip。実行timeoutは15秒
- 通常5秒の既存workspaceテストにtimeoutあり。変更内容の不具合と断定しない
- main変更5ファイルのnixfmt/deadnixとprogram directoryのstatixが成功
- model/account helperの追加テスト7 pass
- Nix system評価は完了せず。Home Manager/system適用は未実施
- Coreは前回358 testと隔離した署名付きMVPが成功。ownerの実運用確認は残る
- Olympusとhomelabのlive接続とUI表示は未検証

# remote開発

必要なrepoだけを配置するworkspace syncは実装済み。host指定の生成APIとaccount確認とsession起動とMac停止中の再接続は縦断未実装。environment登録とsession実行は別の責務として管理する。詳細は[remote readiness](remote-development-readiness-2026-10-05.md)。

# Olympus

既存のread-only SSE viewを再利用する。Core読み取りHTTP projectionを先に整えInbox完了条件とToday/Task表示へ接続する。詳細は[Olympus調査](olympus-harness-integration-2026-10-05.md)。

# 公開境界

秘密値と個人account情報を新しい記録へ入れない。元checkoutの未commit差分を一括pushしない。Draft PRのmergeと実機適用は今回行わない。

# GitHub追跡先

- [dotfiles #18 環境管理](https://github.com/r1cA18/dotfiles/issues/18)
- [Core #60 remote workspace/session](https://github.com/r1cA18/harness-core/issues/60)
- [Olympus #10 完了駆動Inbox](https://github.com/r1cA18/olympus/issues/10)
- [Olympus #2 調査結果](https://github.com/r1cA18/olympus/issues/2#issuecomment-5985807548)
- [Core #27 調査結果](https://github.com/r1cA18/harness-core/issues/27#issuecomment-5985807775)

ブランチ側の回帰テストは69 passと4 skip。変更したNixのformat/deadnixとshell構文検査も成功。ローカル署名は1Password agentの応答失敗。GitHubの署名付きcommit APIで公開しVerifiedを確認。ローカル署名設定は保持。

# 公開結果

- main: [4994911](https://github.com/r1cA18/dotfiles/commit/4994911d5acf28a7a11dd2bd61b389b610589757)
- 別ブランチ: [Draft PR #19](https://github.com/r1cA18/dotfiles/pull/19)
- 両commitのVerifiedとlocal staged tree一致を確認
- mainのBuild/Lint CI成功。Draft PRのsecret scan成功。残るPR CIは公開時点で実行中
- 元checkoutは既存差分を保持。公開用worktreeを別に作成
- 環境適用とremote sessionの実機確認は未実施

# CI追補

PR #19の回帰テストとsecret scanは成功。Prettier不一致とLinux buildのtorchcodec依存テスト失敗を確認。修正commit fcae180で文書をformatしnixpkgsのみmainのbuild成功済みrevisionへ戻した。修正後CIは実行中。元checkoutのlockと他の変更は保持。

# 最終確認

修正head fcae180でLinux build（2分13秒）とcheckとregressionとsecret scanの全4checkが成功。PR #19はDraftで保持。mainへの追加pushと環境適用は行わない。GitHub #18に最終結果を記録する。
