{ pkgs, lib, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
  # 1Password SSH agent のソケット (OS別)。
  # macOS: 1Password.app の Group Container。
  # Linux: 1Password desktop の標準パス (1Password desktop 導入が前提)。
  agentSock =
    if isDarwin then
      "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
      "$HOME/.1password/agent.sock";
in
{
  home.sessionVariables = {
    SSH_AUTH_SOCK = agentSock;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # OrbStack は macOS 専用
    includes = lib.optionals isDarwin [ "~/.orbstack/ssh/config" ];
    settings = {
      "*" = {
        IdentityAgent = "\"${agentSock}\"";
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
