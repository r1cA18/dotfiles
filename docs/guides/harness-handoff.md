# OrcaとCoreによる作業の引き継ぎ

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

1. Coreのcheckpoint対応revisionを隔離checkoutでbuildする
2. 移動元と移動先のCore実行fileを確認する
3. Orcaのreadyなproject host setupまたはpaired runtimeを確認する
4. 移動先のprofileとdevice-local account bindingを確認する
5. fixtureでcheckpointの往復と改ざん拒否を検証する
6. 必要なPRを依存順にmergeした後に既存のNix運用でSkillを配布する

Skillの正本は[agents/skills/harness](../../agents/skills/harness/SKILL.md)。配布対象へ追加済み。Claude・Codexへの配布には既存agent-skills moduleを使う。dshには既存のopt-in `dotfiles.harnessRuntime.dsh.shareSkills`を使う。本変更はHome Managerや既存accountへ適用していない。

SSHで接続できるだけではOrcaのremote terminalを作成できるとは限らない。登録済みSSH targetとpaired runtimeは別の接続種別。installed APIで操作できる接続を確認する。Orca 1.4.219のMac CLIとhomelabの1.4.215で機能範囲を調査した。現状のhomelabはSSH試験が可能だがpaired runtimeの設定は未完了。

## 保存内容と完了の意味

checkpointは複数repoのHEADとstaged/unstaged差分と指定した未追跡ファイルとrepo外assetを保持する。原本のabsolute pathとGit remote設定とaccount credentialは移さない。作成時に試験復元し受信時は独立して保持したdigestで検証する。復元先は新しいdirectoryに限定する。

`prepared`は準備完了。`source_stopped`はOrcaが停止を確認した状態。`restored`はartifactの復元完了。`input_accepted`と`turn_started`も区別する。いずれもtask完了や公開承認を意味しない。

移動元が操作中agent自身のterminalなら停止対象worktreeの外にいるcontrollerが必要になる。同じworktreeの別terminalもworkspace全体の停止対象になる。controllerがなければcontextとcheckpointを保存して`prepared`まで進める。自分を停止した後に処理が続くとは仮定しない。新しい受信agentを起動してこの制限を回避することもしない。

停止確認だけでは復帰した旧workerの二重公開を永続的に防止できない。Coreのgeneric dispatchとPublisher gateは別の未完了項目。profileの中央catalogとdevice bindingは既存の基盤を使うが実subscription推論とcredentialの中央配布を本変更の完成範囲へ含めない。

## 検証範囲

Skill validatorはerror/warningともに0。Mac/Linux両方のHome Manager評価で配布対象への追加を確認した。Nix bundleをbuildしてSkill本文とreferenceがsourceと一致することも確認した。Macはunit99 pass / 7 skipとintegration77 pass / 3 skip。Linuxもunit99 pass / 7 skipとintegration77 pass / 3 skipを確認した。Linux integrationの初回は変更外の既存fzf testが一時pathのfuzzy matchで1件失敗し再実行で成功した。通常suiteのnative dsh 3 skipはMacで別実行し3 pass / 0 failとなった。

CoreはMacとLinuxで各388 testsとfmtとClippyが成功。導入用`harness-core/scripts/validate-checkpoint.py`によるMac→homelab→Macの合成fixture往復は4.237秒で成功した。Orca 1.4.215の隔離runtimeでもGit repo登録とshell terminal作成とworkspace全体の停止が成功した。一時displayとnative config homeを用意し試験後にserverとdisplayを停止した。

SkillのFormat・参照・依存と失敗時手順を自己reviewした。context復旧のみを扱うsession-handoffとは役割を分けた。LLMによるSkill選択は未評価。Macからpaired runtimeへのRPCと生きたagentの自動移動と実subscription推論は未検証。UI変更はない。
