# Orca settings管理境界の修正

## 目的と受入条件

Issue #16を対象にHome Managerの旧JSON settings writerを削除する。runtime file・SQLite・account・defaultsへ書き込まずCLIとcredential helpersを維持する。Nix parse・formatter・関連buildで変更を検証する。

## 確認と変更

- clean HEADから隔離したcheckoutで実装
- `activation.orcaSettings`によるprofileごとの旧JSON backupとsettings mergeを確認して削除
- Orca 1.4.219のCLI helpにsettings更新commandがないことを確認
- live settingsはOrcaのSQLite管理とし旧JSON snapshotは未適用の参照として保持
- `desklab`の参照は大文字小文字を区別しない検索でも存在しない
- `r1ca18lab`との対応は未確認のためhost設定は変更しない
- runtime stateとcloud resourceの操作は未実施

## 検証と次の作業

- `nix-instantiate --parse nix/home-manager/programs/orca.nix`成功
- 変更した4fileの`nix fmt -- --fail-on-change`成功
- RMBのHome Manager activation package build成功
- 生成activationに旧writerの識別子とprofile JSON・SQLite参照がないことを確認
- `git diff --check`成功
- Home Manager適用とOrca UIのruntime変更は未実施

implementation PRを作成して独立reviewを待つ。
