# Self-hosted unified messenger調査とworkspace準備

確認日: 2026-10-21
状態: 調査と開発workspace準備完了

## 目的

Matrixを共通基盤にした個人用messengerの詳細調査と開発workspaceを作成する。WebとiPhone/iPadを対象とし将来のAndroid追加に備える。Instagram・Discord・LINE・LinkedIn・Slack・Telegram・X・WhatsApp・Google Chatの9サービスを対象にする。

## 成功条件

- 9サービスの既存bridge・認証・制約・出典を記録
- Matrix準拠の境界とrepo構成と採用stackを説明
- driverの追加・無効化・更新・削除の契約を定義
- 既存のworkspace運用に沿う独立した開発workspaceを作成
- manifestとworkspace操作を検証して未検証項目を明記

## 決定

- 所有者が個人用優先を選択
- アプリの通信はMatrix Client-Server APIを基本とする
- upstream bridgeを優先評価して不足時だけ別repoのgatewayを作成
- 実装の存在と実アカウントでの動作確認を区別
- 公開・remote作成・production deployは今回の準備作業に含めない

## 進捗

- dotfilesのinstructionsとarchitectureとmulti-repo workspaceガイドを確認済み
- 9サービスすべてにMatrix bridge候補を確認済み
- READMEとROADMAPと認証docsをGitHub connectorと組み込みWebで確認
- LINEにはbeeper/lineが存在する
- Discordはlegacy Go構成と確認
- Google ChatはPython構成と確認
- Telegramは現在Go構成と確認
- 技術stack比較・認証API・E2EE・通知・driver運用を調査済み
- 独立workspaceのselfhost-chatに詳細調査と設計とADRとUI briefと実装計画を保存
- WebはReactとMatrix JS SDKを初期採用
- AppleはSwiftUIとMatrix Rust SDKを初期採用
- homeserverはSynapseとPostgreSQLを初期採用
- 5つの自作Git repoをbootstrap
- upstream 9repoをcloneして調査時のcommitへ固定
- 7catalog testsと9repoのsource pin照合が通過
- bootstrapの再実行で既存21fileを保持
- 最終配置後も7testsと9repoのsource pinと25相対linkを確認
- 詳細な進捗と未検証項目の正本は新workspaceのdocs/tasks/000-research-and-workspace.mdとdocs/verification.md

## 次の作業

deployment repoで検証用Synapseと通常Matrix DMを構築する。外部サービスへのloginと実送受信とapp本体は未実施。dotfilesの既存変更は変更していない。
