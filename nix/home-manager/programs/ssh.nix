{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  # 1Password SSH agent のソケット (OS別、ホームからの相対パス)。
  # macOS: 1Password.app の Group Container。
  # Linux: 1Password desktop の標準パス (1Password desktop 導入が前提)。
  agentSockRel =
    if isDarwin then
      "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
      ".1password/agent.sock";
in
{
  # shell 用は $HOME 展開、ssh config 用は ~ 展開と展開規則が異なるため分離。
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/${agentSockRel}";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # OrbStack は macOS 専用
    includes = lib.optionals isDarwin [ "~/.orbstack/ssh/config" ];
    settings = {
      "*" = {
        IdentityAgent = "\"~/${agentSockRel}\"";
      };
      homelab = {
        User = "r1ca18";
      };
      rlc = {
        SetEnv.TERM = "xterm-256color";
      };
    };
  };
}
