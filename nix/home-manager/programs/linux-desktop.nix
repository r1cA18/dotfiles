{ pkgs, lib, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  # 非NixOS (Ubuntu) で home-manager を standalone 運用するための定番設定。
  # XDG_DATA_DIRS 等に Nix profile を注入し、man / シェル補完 /
  # デスクトップ統合 (.desktop, アイコン) を OS 側に認識させる。
  targets.genericLinux.enable = true;

  # GUI 端末 (Ghostty 等) で Nerd Font グリフを解決するため。
  # これにより手動 fc-cache が不要になる。
  fonts.fontconfig.enable = true;
}
