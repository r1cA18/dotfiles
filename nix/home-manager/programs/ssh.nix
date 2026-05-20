{ pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          IdentitiesOnly = "yes";
        };
      };
      "homelab" = {
        user = "r1ca18";
      };
    };
  };
}
