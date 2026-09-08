---
title: MacとLinuxの機能差分と管理境界
created: 2026-09-06
type: research
tags: [dotfiles, nix, linux, macos, platform-parity]
---

# MacとLinuxの機能差分と管理境界

## 調査範囲

2026-09-06のworking treeを対象にした。既存の未コミット変更を含むため、以下はGitのHEADだけの状態ではない。Nix設定の適用やremote hostの変更は行っていない。

CLIとagentの共通基盤はすでにHome Managerへ集約されている。主な不足は共通化そのものよりも、GUI本体の導入漏れを設定の配布と区別できていないこと、宣言と実機を照合する検証の不足にある。

## 証拠と限界

| 種類              | 確認内容                                               | 扱い                                 |
| ----------------- | ------------------------------------------------------ | ------------------------------------ |
| 現在のsource      | flake・Home Manager・nix-darwin・Ansible・CI・運用docs | 宣言についての確定事実               |
| 前回のLinux実測   | 2026-09-05のplatform auditに残った平文tool結果         | その時点の稼働事実                   |
| 今回のLinux再接続 | 既存SSH aliasの`homelab`へ接続                         | sandbox外の再試行でも接続timeout     |
| 現在の実機状態    | 再接続できなかったため未確認                           | 前回の結果から現在の稼働を断定しない |
| GUI・GPU・音声    | 今回は未操作                                           | packageの有無から動作を断定しない    |

前回のLinux checkoutは`448e295`だった。sessionの暗号化部分は読まず、tool結果の平文部分だけを回収した。credential・email・private IP・device IDは本書へ転記していない。

## 管理境界

| 層                             | macOS                                     | Linux                                         | 判断                       |
| ------------------------------ | ----------------------------------------- | --------------------------------------------- | -------------------------- |
| OS・daemon・GUI本体            | `nix/darwin/configuration.nix`            | `homelab/ansible/playbook.yml`                | 既存境界を維持             |
| shell・CLI・editor設定         | `nix/home-manager/home.nix`               | 同じ`home.nix`をhostからimport                | 共通資産                   |
| host固有service                | nix-darwinまたはlaunchd                   | `nix/home-manager/hosts/homelab.nix`とAnsible | host役割に応じた差         |
| 共有agent instructions         | `agents/INSTRUCTIONS.md`と`agents/rules/` | 同じsource                                    | Nixで結合して配布          |
| skills                         | `agents/skills/`とflake inputs            | 同じsourceと有効化リスト                      | 配布と実行条件は別         |
| account・session・plugin cache | 製品ごとのruntime state                   | 製品ごとのruntime state                       | OS間で一括同期しない       |
| repo保管                       | `~/Develop`をghq rootに設定               | 同じ相対構造                                  | workspace導入時も維持可能  |
| vault・Develop同期             | Syncthing service                         | Syncthingとfolder定義                         | sourceとruntime dataが混在 |

Linuxの`dr`はHome Managerだけを適用する。systemのpackage・firewall・daemonまで含める場合は`homelab-apply`を使う。Macの`dr`とコマンド名が同じでも適用範囲は異なる。

## 機能差分

「宣言あり」は本体や設定の生成先が存在する意味であり、認証やGUIの動作確認済みという意味ではない。

| 機能                                 | macOS宣言                  | Linux宣言                       | 前回Linux実測            | 判定・次の扱い                            |
| ------------------------------------ | -------------------------- | ------------------------------- | ------------------------ | ----------------------------------------- |
| Zsh・Git・ghq・Neovim                | 共通Home Manager           | 共通Home Manager                | Git・ghq・Neovimあり     | 共通化済み                                |
| Bun・Node・pnpm                      | `commonPackages`           | 同左                            | あり                     | 現在のworking treeはglobal供給を選択済み  |
| ripgrep・agent-browser・difit・Herdr | 共通package                | 同左                            | あり                     | 共通化済み                                |
| typst・ffmpeg・ast-grep              | 共通package                | 同左                            | 今回の回収結果では未確認 | 次回CLI probe対象                         |
| Codex・Claude・Antigravity           | native bootstrapとupdater  | 同左                            | CLIあり                  | 最新版追従とNix lockの責任を区別          |
| Gemini CLI                           | 共通package                | 同左                            | あり                     | provider認証は個別                        |
| `cxp`・`clp`                         | 共通profile manager        | 同左                            | manager単体は未確認      | account分離方式は共通                     |
| `clgpt`・`clproxy`                   | launchdでon-demand         | systemd user serviceでon-demand | proxyはinactive          | 待機中のinactiveは異常ではない            |
| Codex app-server                     | このhomelab serviceはなし  | Nix版binaryをsystemdで常駐      | active                   | CLIとのversion差は意図した分離            |
| Olympus MCP                          | SSHでhomelabへ接続         | 同じrepoのentrypointをlocal実行 | 登録確認は未回収         | 同一機能のOS別transport                   |
| shared skills                        | 全global skillを配布       | 同じ全global skillを配布        | 全skill実行は未確認      | Xcode系をLinuxで実行できる意味ではない    |
| Ghostty                              | Homebrew本体と共通設定     | 設定のみ・`package = null`      | 本体なし                 | GUI用途の導入候補                         |
| Zed                                  | Homebrew本体と設定         | `settings.json`のみ             | 本体なし                 | GUI用途の導入候補                         |
| Tailscale                            | CLIとGUI                   | AnsibleのAPTとsystemd           | CLIあり                  | 管理方法の差は意図的                      |
| Ollama                               | CLIとGUI                   | Ansibleに本体・service宣言なし  | 本体なし                 | 利用予定とresource要件を決めてから導入    |
| Chrome・1Password                    | Homebrew                   | Ansibleの公式deb                | 本体あり                 | browser loginとSSH Agent unlockは別確認   |
| ChatGPT desktop                      | 本調査のcask一覧に宣言なし | Ansibleの公式deb                | 本体あり                 | Mac側の導入元を別途棚卸し                 |
| Syncthing                            | service宣言                | serviceとfolder定義             | active                   | Mac側folder設定は同じ宣言管理ではない     |
| Claude通知音                         | `afplay`                   | `canberra-gtk-play`             | Linux commandあり        | headless sessionでの可聴性は未確認        |
| Superset通知                         | optional hook              | optional hook                   | 未確認                   | 実行file不在時はno-opになる               |
| Xcode・fastlane・xcodegen・Karabiner | macOS専用                  | なし                            | 対象外                   | OS固有の差を維持                          |
| TeX一式                              | `texliveFull`              | なし                            | 対象外                   | Linuxで必要な文書workflowが出た時点で検討 |

GhosttyをNixで入れていないのはGTK・OpenGLとsystem libraryの整合性を考慮した既存方針であり、`package = null`を一律に解除する修正は行わない。導入するなら現在のUbuntuとGPU構成で動く供給元を確認し、Ansible側へ明示する。

## 優先する改善

| 優先度 | 発見                                                                             | 具体的な対応                                                                               |
| ------ | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 高     | native移行後もMCP検査が旧Nix profileのCodexを参照していた                        | 今回`homelab/scripts/doctor.sh`をnative CLIとprimary profileの明示へ修正済み・remote未適用 |
| 高     | SyncthingがDevelopの`.git`・build生成物・runtime DBを双方向同期                  | 現行の片側操作ルールを維持・workspaceから同一repoを両hostで同時編集しない                  |
| 中     | `packages.nix`のOllamaコメントがLinuxの対応宣言と不一致だった                    | 今回LinuxのOllamaは未導入と修正済み・本体導入は利用要件確定後                              |
| 中     | GUIの設定配布が本体導入と混同されやすい                                          | Ghostty・Zedを「設定のみ」と運用表に明記・必要なものだけAnsibleへ追加                      |
| 中     | 常設CLI版とapp-server版Codexの更新経路が異なる                                   | doctor結果へ両versionと実行fileを出せるようにする                                          |
| 中     | Linux CIはあるがDarwin build jobがない                                           | 共通module変更でDarwinとLinuxのevalを両方確認・Mac buildはlocalまたは専用runner            |
| 中     | skill配布は同一でもmacOS依存がある                                               | skill入口でOSとCLI条件を確認・対応OSをskill棚卸し台帳へ記録                                |
| 低     | `aarch64-linux`のpackage・formatter outputはあるがhost configurationはx86_64だけ | ARM Linuxを使う予定が出るまでhostを増やさない                                              |

node・pnpmのglobal供給とproject devShellの責任は既存変更が進行中なので、古いarchitecture記述だけを根拠に削除しない。宣言の最終状態が決まった後にdocsを揃える。

## Workspaceとの関係

ghq rootを変えず、workspaceは目的・repo対応表・共通指示を保持する層にするのが現在の構造に合う。各hostのhome directoryが異なるため、Macの絶対symlinkをLinuxへ同期して使い回す構成にはしない。

workspace manifestにrepoのghq相対pathを記録し、linkやeditor用設定は各hostで生成する。同じrepoのGit操作とdevShellの責任はrepo側へ残す。`.git`と稼働中DBを含む現在のDevelop同期方式を変更する場合は、workspace導入とは別に停止手順・復旧手順・backupを検証する。

account profileの共有linkは同じmachine内のprimary profileから張るものだ。認証情報・session SQLite・plugin cacheをSyncthingへ追加してOS差を解消しようとしない。session引継ぎは必要な履歴と作業状態を選んで渡す。

## 検証コマンド

本調査を受けてdoctorのCodex参照先とOllamaのコメントを修正した。doctorは変更前後の`bash -n`を通過した。本文のpath lintと`git diff --check`も通過した。remoteへの適用と稼働確認は未実施となる。

統合時のDarwin system derivation評価は成功した。LinuxのactivationPackage評価は既存video-editing skill生成がLinux用ffmpeg等のbuildを要求し、Mac上のoffline評価ではplatform mismatchとなった。Linux側のbuildと稼働確認は残る。以下は再検証手順であり、dirtyなtracked fileはflake評価に含まれるが新規untrackedなsourceは通常のGit flake評価に含まれない点に注意する。今回の評価には新規skillを含めるため`path:`形式を使った。

```bash
# Mac側: DarwinとLinuxの宣言を評価する
nix eval --no-write-lock-file --raw '.#darwinConfigurations.RMB.system.drvPath'
nix eval --no-write-lock-file --raw '.#homeConfigurations."r1ca18@homelab".activationPackage.drvPath'

# Mac側: 適用せずbuildする
nix build --no-write-lock-file --no-link '.#darwinConfigurations.RMB.system'

# Linux側: 適用せずbuildする
nix build --no-write-lock-file --no-link '.#homeConfigurations."r1ca18@homelab".activationPackage'
nix build --no-write-lock-file --no-link '.#checks.x86_64-linux.homelab'

# 各hostの対話shell: 共通コマンドとprofile manager
command -v nix bun ghq rg nvim herdr agent-browser difit
cxp doctor
clp doctor

# Linux側: native CLIとsystemdの実行fileを比較する
"$HOME/.local/bin/codex" --version
systemctl --user show codex-app-server.service -p ExecStart --value
systemctl --user is-active codex-app-server.service syncthing.service
CODEX_HOME="$HOME/.codex" "$HOME/.local/bin/codex" mcp get olympus

# 文書pathとshell構文
bash scripts/lint-doc-paths.sh
bash -n homelab/scripts/doctor.sh
```

前回probeで`nix:missing`だったのは非対話SSH環境での`command -v`の結果に限られる。Nix自体の未導入を意味しない。再確認ではlogin shellのPATHと実行fileの有無を分けて調べる。

`homelab-doctor`はserviceの状態やネットワーク情報を出力する。結果を公開文書へ貼る場合はprivate情報を除く。稼働中の同名serviceがあることと、最新working treeを適用済みであることも分けて確認する。

## 参照元

- [全体構造](../architecture.md)
- [Agentの管理境界](../agent-platforms.md)
- [Profile管理](../guides/agent-profiles.md)
- [Ubuntu運用](../../homelab/README.md)
- [Ubuntu GUI設定方針](../../nix/docs/guide-ubuntu.md)
- [共通package定義](../../nix/home-manager/programs/packages.nix)
- [Homelabのuser service](../../nix/home-manager/hosts/homelab.nix)
- [System provisioning](../../homelab/ansible/playbook.yml)
- [既存doctor](../../homelab/scripts/doctor.sh)
- [Build CI](../../.github/workflows/build.yaml)
- [Lint CI](../../.github/workflows/lint.yaml)
