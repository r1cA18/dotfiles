{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.harnessRuntime;
  scripts = pkgs.runCommand "harness-runtime-scripts" { } ''
    mkdir -p "$out"
    cp ${../../../agents/scripts/model-connection.ts} "$out/model-connection.ts"
    cp ${../../../agents/scripts/harness-runtime.ts} "$out/harness-runtime.ts"
  '';
  command =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.bun ];
      text = ''
        exec bun ${scripts}/${script} "$@"
      '';
    };
in
{
  options.dotfiles.harnessRuntime.enable = lib.mkEnableOption "opt-in harness connection planning and explicit runtime launch";
  config = lib.mkIf cfg.enable {
    home.packages = [
      (command "harness-connection" "model-connection.ts")
      (command "harness-runtime" "harness-runtime.ts")
    ];
  };
}
