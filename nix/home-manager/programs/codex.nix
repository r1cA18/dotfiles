{
  username,
  pkgs,
  lib,
  ...
}:
let
  dotfilesDir = "/Users/${username}/dotfiles";
in
{
  # config.toml が存在しない場合のみテンプレートをコピー
  home.activation = lib.mkIf pkgs.stdenv.isDarwin {
    codexConfigSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.codex/config.toml" ]; then
        mkdir -p "$HOME/.codex"
        cp "${dotfilesDir}/codex/config.toml" "$HOME/.codex/config.toml"
        echo "Codex config.toml created from template"
      fi
    '';
  };
}
