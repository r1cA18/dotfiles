{ pkgs, ... }:
let
  assets = pkgs.runCommand "harness-model-profile-assets" { } ''
    mkdir -p "$out/scripts"
    cp ${../../../agents/scripts/model-profile.ts} "$out/scripts/model-profile.ts"
    cp -R ${../../../agents/model-profiles} "$out/model-profiles"
  '';
  modelProfiles = pkgs.writeShellApplication {
    name = "harness-model-profile";
    runtimeInputs = [ pkgs.bun ];
    text = ''
      exec bun ${assets}/scripts/model-profile.ts "$@"
    '';
  };
in
{
  home.packages = [ modelProfiles ];
}
