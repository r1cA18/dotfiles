# Formatter and Linux server workflow entrypoints.
{
  inputs,
  pkgs,
  system,
  formatter,
}:
let
  inherit (inputs) home-manager;
  serverManager = pkgs.writeShellApplication {
    name = "server";
    runtimeInputs = [
      pkgs.ansible
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.systemd
      home-manager.packages.${system}.default
    ];
    text = builtins.readFile ../../server/scripts/manage.sh;
  };
  mkServerApp = action: {
    type = "app";
    program = "${
      pkgs.writeShellApplication {
        name = "server-${action}";
        runtimeInputs = [ serverManager ];
        text = ''
          exec server ${action} "$@"
        '';
      }
    }/bin/server-${action}";
    meta.description = "Run the server ${action} workflow";
  };
in
{
  fmt = {
    type = "app";
    program = "${formatter}/bin/treefmt";
    meta.description = "Format the dotfiles repository";
  };
}
// pkgs.lib.optionalAttrs (system == "x86_64-linux") {
  server-apply = mkServerApp "apply";
  server-restore = mkServerApp "restore";
  server-start = mkServerApp "start";
  server-stop = mkServerApp "stop";
  server-rdp-setup = mkServerApp "rdp-setup";
  server-doctor = mkServerApp "doctor";
}
