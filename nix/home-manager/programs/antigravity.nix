{
  lib,
  pkgs,
  ...
}:
let
  updateAntigravity = pkgs.writeShellApplication {
    name = "update-antigravity";
    runtimeInputs = with pkgs; [
      curl
      bash
    ];
    text = ''
      if command -v agy >/dev/null 2>&1; then
        echo "[antigravity] updating via agy update..."
        agy update || curl -fsSL https://antigravity.google/cli/install.sh | bash
      else
        echo "[antigravity] installing to latest..."
        curl -fsSL https://antigravity.google/cli/install.sh | bash
      fi
    '';
  };
in
{
  home = {
    packages = [ updateAntigravity ];

    activation = {
      # Antigravity CLI (agy) native 版の自動導入。
      # 更新は du の update-antigravity (または agy update) が担う。
      setupAntigravity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        bin="$HOME/.local/bin/agy"
        if [ ! -x "$bin" ]; then
          echo "[antigravity] installing agy..."
          ${pkgs.curl}/bin/curl -fsSL https://antigravity.google/cli/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';
    };
  };
}
