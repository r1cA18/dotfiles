# OrcaとCoreによる作業の引き継ぎ

最新の導入候補と実装・実機検証の区別は[導入状況](harness-adoption.md)を参照する。
以下には過去の検証結果を含む。現在の接続状態は試験時に再確認する。

開発の入口には共有Skill `harness`を使う。Orca MCPまたはversionに対応したCLIがhost・worktree・terminalを操作しCoreのcheckpointが作業内容を保存・検証・復元する。local/cloudと移動方向で別の仕組みを作らない。OS名による割り振りは行わず必要toolとdevice accessと空きresourceから既存hostを選ぶ。

## 操作

| 入力例                                                                                   | 動作                                   |
| ---------------------------------------------------------------------------------------- | -------------------------------------- |
| `/harness status`                                                                        | 接続先とterminalと選択状態を確認       |
| `/harness offload --host <host>`                                                         | 新しい作業を既存hostへ配置             |
| `/harness reconnect --host <host>`                                                       | 動いている既存terminalへ再接続         |
| `/harness handoff --host <host>`                                                         | 停止確認後に作業を保存して別hostへ復元 |
| `/harness handoff --host <host> --runtime <runtime> --profile <profile> --group <group>` | 移動先と独立した選択変更を指定         |
| `/harness branch --host <host>`                                                          | 元の作業を残して別の仕事として分岐     |

これらはagentが解釈するSkillの引数。新しいnative command registryは追加していない。固定dshのuser-invocable Skillは`/name`から呼び出せる。Claude・Codexでは利用中clientが対応するSkill呼出形式を使う。指定を省いたruntime/profile/groupは維持し接続できない場合に別accountへ自動変更しない。

## 導入前の確認

1. Coreの`handoff capture`とcheckpoint対応revisionを隔離checkoutでbuildする
2. 移動元と移動先のCore実行fileを確認する
3. Orcaのreadyなproject host setupまたはpaired runtimeを確認する
4. 移動先のprofileとdevice-local account bindingを確認する
5. fixtureでcheckpointの往復と改ざん拒否を検証する
6. 必要なPRを依存順にmergeした後に既存のNix運用でSkillを配布する

Skillの正本は[agents/skills/harness](../../agents/skills/harness/SKILL.md)。配布対象へ追加済み。Claude・Codexへの配布には既存agent-skills moduleを使う。dshには既存のopt-in `dotfiles.harnessRuntime.dsh.shareSkills`を使う。本変更はHome Managerや既存accountへ適用していない。

capture requestとCLI引数と復旧手順は[Coreのcontroller guide](https://github.com/r1cA18/harness-core/blob/106215d71d65a3d1442374e8e4d11f1ca30d2f2f/docs/handoff-controller.md)にまとめた。profileの中央catalogとdevice bindingは[model connections guide](model-connections.md)を使う。doctorの`ready`は定義の整合性を示す。native loginと実推論の成功は別に確認する。

SSHで接続できるだけではOrcaのremote terminalを作成できるとは限らない。登録済みSSH targetとpaired runtimeは別の接続種別。installed APIで操作できる接続を確認する。Orca 1.4.219のMac CLIとhomelabの1.4.215で機能範囲を調査した。過去のhomelab試験ではSSH接続を使用したがpaired runtimeは設定していない。最新の接続可否は導入状況と実際のdiscoveryで確認する。

## 保存内容と完了の意味

checkpointは複数repoのHEADとstaged/unstaged差分と指定した未追跡ファイルとrepo外assetを保持する。原本のabsolute pathとGit remote設定とaccount credentialは移さない。作成時に試験復元し受信時は独立して保持したdigestで検証する。復元先は新しいdirectoryに限定する。

`prepared`は準備完了。`source_stopped`はOrcaが停止を確認した状態。`restored`はartifactの復元完了。`input_accepted`と`turn_started`も区別する。いずれもtask完了や公開承認を意味しない。

移動元が操作中agent自身のterminalなら停止対象worktreeの外にいるcontrollerが必要になる。同じworktreeの別terminalもworkspace全体の停止対象になる。外部controllerはsource hostで`harness-core --json handoff capture`を実行する。SSH経由でも同じCLIを使う。controllerがなければcontextとcheckpointを保存して`prepared`まで進める。

`handoff capture`は停止intentを保存してからOrcaの停止receiptを確認しcheckpointを作る。`captured`になればoperation directory内の`checkpoint/`と独立して保持した`checkpoint_digest`を使う。完成済み要求の再実行はartifactを検証するだけで新しいterminalを停止しない。未完了の場合は`handoff show`で確認して手動で整合させる。自動で別directoryを選んで再試行しない。確認済みversionはOrca 1.4.215と1.4.219。

controllerは自身のcwdとOrca terminalのworktree identityを検査する。同じterminalで`cd`しただけでは外部controllerにならない。`captured`はsource側の停止後保存が終わった状態でありdestinationの復元やagent再開や権限移譲は意味しない。

停止確認だけでは復帰した旧workerの二重公開を永続的に防止できない。Coreの明示dispatchは#67で実装済み。check/commentのPublisher gateは#69で実装済み。本番のcredential分離とDraft PR/push経路は未完了。これらをlive agentの通し引き継ぎ成功とは扱わない。profileの中央catalogとdevice bindingは既存の基盤を使うが実subscription推論とcredentialの中央配布を本変更の完成範囲へ含めない。

## 検証範囲

Skill validatorはerror/warningともに0。配布定義は既存PR #27でMac/Linux両方のHome Manager評価とNix bundle buildを確認済み。今回もMacでbundleをbuildし本文とreferenceがsourceと一致した。配布先とoptionの変更はない。テスト整理PRを基準にMac/Linuxのallは各110 pass / 3 native-dsh skip / 0 fail。fzf試験の不安定さは再現して修正済み。native dshはCIが固定packageを指定して別途検証する。

CoreはMacとLinuxで各397 testsとfmtとClippyが成功。`harness-core/scripts/validate-checkpoint.py`による2 repoとassetのMac→homelab→Macの往復も成功した。`harness-core/scripts/validate-handoff-controller.py`はLinuxの隔離Orca 1.4.215で実terminalの停止→capture→復元を確認し新しいterminalを再実行が閉じないことも確認した。一時displayとnative config homeを用意し所有するserverとdisplayを試験後に停止した。

SkillのFormat・参照・依存と失敗時手順を自己reviewした。Single＋Referencesの構成を保ち決定的な停止・保存をCoreへ任せる。context復旧のみを扱うsession-handoffとは役割を分けた。手動fixture導入に向けた判定はReady。LLMによるSkill選択は未評価。Macの実terminal停止とpaired runtimeへのRPCと生きたagentの自動移動と実subscription推論は未検証。UI変更はない。
