---
title: dotfiles環境整理の進捗
created: 2026-10-04
type: research
tags: [nix, environment, progress]
---

# dotfiles整理の進捗

## 目的と完了条件

廃止したDesklabのhost設定を削除しNix構成の責務と重複を整理する。既存の未commit変更を保持し残存hostと各OSのpackage定義を変更前後で比較する。文書参照と回帰testとNix buildを確認する。

## 判断

- flake entrypointからhost構成と開発環境とapp定義を分離する
- formatterとpre-commit hooksの定義をcheckとdevShellで共有する
- mdvの実装を他のcustom packageと同じ配置へ移す
- flake-parts追加やprogram module全体の移動は行わず既存の配置を維持する
- 本人の回答でDesklabはr1ca18labと確認。host定義とREADMEのbuild手順を削除した

## 変更前の確認

- 既存の未commit変更は23ファイルと複数の新規ファイルに存在
- Darwin host一覧はRMBとMBP187-Zとr1ca18lab
- sandbox内のunit testは61 passと4 skipと1 fail。失敗は実terminalのPTY操作に対するoperation not permitted
- 必要な権限で変更前unit testを再実行し62 passと4 skipと0 fail

## 完了した変更と検証

- flake.nixを373行から162行へ縮小。host構成・開発環境・appをnix/flakeへ分離
- mdvをnix/pkgs/mdv/default.nixへ移動。既存のorca-ide追加を保持
- READMEとarchitectureの配置説明を更新
- 削除前後のNix評価でr1ca18labだけがhost一覧から除かれたことを確認
- 残存hostの主要設定値と全3OSのpackage drvPathとoutput一覧とformatter drvPathが変更前と一致
- RMBとMBP187-Zの最終system buildが成功。設定適用は未実施
- 変更後unitは62 passと4 skipと0 fail。integrationは40 passと0 fail
- 全OSのnix flake check --no-buildが成功。Linuxの実buildと実機適用は未検証
- 変更したNix fileのdeadnixとstatixとformatterが成功。文書参照lintとgit diff --checkも成功
- 全体formattingとpre-commitのbuildは既存fileのformat不一致で失敗。変更前のcopyでも同じ検査が失敗
- 整理対象外の既存tracked変更は作業前copyとのbyte比較で一致

## 残る確認

今回の整理とhost削除は完了。全体format checkの不一致は別の整理対象として残る。system設定の適用とcommitは未実施。
