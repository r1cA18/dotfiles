# homelab

Ubuntu Desktopをhome server・常駐agent host・持ち出し可能なdemo machineとして再現する構成。

## 管理境界

| 層               | 管理対象                                         | Source of truth                                                 |
| ---------------- | ------------------------------------------------ | --------------------------------------------------------------- |
| Ubuntu system    | SSH・Docker・Tailscale・firewall・power・GUI app | `ansible/playbook.yml`                                          |
| User environment | CLI・shell・agent・Syncthing                     | `nix/home-manager/hosts/homelab.nix`                            |
| Service          | Home Assistant・ESPHome                          | `~/Develop/github.com/r1cA18/home-assistant/docker-compose.yml` |
| Runtime data     | HA registry・database・secret・ESPHome secret    | 上記repository内のGit除外file                                   |
| Secret           | Interactive secret・将来のservice token          | 1Password                                                       |

Runtime dataとsecretはGitへ入れず、`Develop`のSyncthing同期で新PCへ移す。Home Assistant側repositoryの`docker-compose.yml`がservice構成のsource of truthになる。初回移行はruntime dataと同じHome Assistant`2026.6.2`と、最後にbuild確認したESPHome`2026.5.3`へ固定済み。回帰確認後に意図的にupgradeする。

Ubuntu install時のdisk encryptionは意図的に無効。端末を紛失した場合は`vault`・source code・Home Assistant credentialを物理的に読まれる前提で扱う。

## 1. Bootstrap

Ubuntu Desktop 26.04 LTSへ`r1ca18`でloginする。このprofileは実機と同じ26.04へ固定し、別releaseへの誤適用をfail-fastで防ぐ。

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y \
  ca-certificates \
  curl \
  git \
  python3 \
  xz-utils

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

この段階ではNix installer・repository clone・Ansible実行に必要なpackageだけを入れる。SSH・rsyncを含むsystem packageは`homelab-apply`が管理する。

Nix installerの案内どおりterminalを開き直す。`nix --version`が通ってからcloneする。

```bash
nix --version

git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Ubuntu system設定とHome Managerを一括適用する。初回はHome Assistantを起動しない。2回目以降も起動状態は現状維持になる。AnsibleとHome Managerは`flake.lock`で固定されたものを使う。

```bash
nix run .#homelab-apply
```

`homelab-apply`はHome Managerの`zsh`をlogin shellとして登録する。一度logoutして入り直す。これでdefault shell・`docker` group・hardware access groupが反映される。

## 2. Tailscale

```bash
sudo tailscale up
sudo tailscale set \
  --advertise-exit-node=true \
  --hostname=homelab \
  --operator=r1ca18
```

Tailscale admin consoleでexit nodeを承認する。旧homelabと名前が衝突する場合は旧deviceを停止・削除してから再実行する。

## 3. Syncthing

Linux側はRMBのdevice IDと次のfolder IDを宣言済み。

| Folder  | ID            | Path        |
| ------- | ------------- | ----------- |
| vault   | `ecvg9-qifz9` | `~/vault`   |
| Develop | `tj9sr-r4ieg` | `~/Develop` |

```bash
systemctl --user status syncthing
syncthing device-id
```

Mac側のSyncthing UIで新しいhomelab deviceを承認する。既存の旧homelab device IDは新PCと異なるため削除する。

続いて`vault`と`Develop`のfolder shareを承認する。両方が`Up to Date`になるまでHome Assistantを起動しない。

`vault`と`Develop`は除外なしの双方向同期にする。`Develop`は`.git`と生成物も含む。同期中に両端で同じrepositoryを操作しない。branch切替・rebase・大量生成の前は反対側の操作が止まっていることを確認する。

30日分のstaggered versioningは新homelab側で有効になる。これはbackupの代替ではない。

## 4. Home AssistantとESPHomeの再デプロイ

Mac側の`~/Develop/github.com/r1cA18/home-assistant`には旧homelabから同期した完全なruntime dataがある。Git管理外の`.storage`・database・secretもSyncthingで新PCへ渡るため、別の空configやarchiveを作らない。

新PCで同期完了後に必須fileを確認する。

```bash
cd ~/Develop/github.com/r1cA18/home-assistant
test -f docker-compose.yml
test -d config/.storage
test -f config/secrets.yaml
test -f esphome/secrets.yaml
```

Home Assistantを有効化する。

```bash
cd ~/dotfiles
nix run .#homelab-start
```

`homelab-start`は必須runtime dataとCompose構文を検証してからsystemd serviceを有効化する。Home AssistantとESPHomeが一緒に復元される。既存構成の`host` network・BlueZ D-Bus・capability・device設定をそのまま保つ。

```bash
cd ~/Develop/github.com/r1cA18/home-assistant
docker compose ps
docker compose logs -f homeassistant
ls -l /dev/serial/by-id
```

`http://homelab.local:8123`でUI・automation・HomeKit・Bluetooth・ESPHome deviceを確認する。HomeKit bridgeのpairing identityも`.storage`から引き継がれる。

持ち出し前などにserviceを明示的に停止・無効化する場合は次を使う。

```bash
cd ~/dotfiles
nix run .#homelab-stop
```

start・stopはsystem provisioningを再実行しないためofflineでも利用できる。

## 5. ChatGPTと1Password

Ansibleが公式`.deb`をinstallする。packageが追加する署名済みAPT repositoryから更新される。

```bash
chatgpt
1password
```

1PasswordのSSH Agentを有効にする。常駐serviceにsecretが必要になった時点で1Password Service Accountを追加する。現在はsecretを必要とするCompose serviceがないためtokenを配置しない。

Claude Codeも使う場合はnative installerで一度だけ導入する。以後は`du`が明示的に更新する。

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

## 6. Firewall

すべてのserviceはTailscaleから利用できる。home LANの`192.168.0.0/24`にはHome Assistant・HomeKit・Syncthing・discoveryだけを公開し、SSHとESPHome dashboardは公開しない。Tailscale exit node向けのforwardingだけを明示的に許可する。

home LANのsubnetを変更した場合は`ansible/playbook.yml`の`homelab_lan_networks`を更新して`homelab-apply`を再実行する。持ち出し先のprivate LAN全体を自動的に信頼しない。

## 7. 検証

```bash
cd ~/dotfiles
nix run .#homelab-doctor
```

ChatGPT Linux previewではComputer Useがまだ使えない。local project・file・Codexは利用できる。Wayland native modeはexperimentalなので通常はXWaylandのまま使う。
