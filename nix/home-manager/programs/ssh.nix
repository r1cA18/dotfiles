{ pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.orbstack/ssh/config" ];
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
        };
      };
      "homelab" = {
        user = "r1ca18";
      };
      "rlc" = {
        extraOptions = {
          SetEnv = "TERM=xterm-256color";
        };
      };
    };
  };
}
