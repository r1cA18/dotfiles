pkgs:
{
  agent-browser = pkgs.callPackage ./agent-browser { };
  difit = pkgs.callPackage ./difit { };
  mdv = pkgs.callPackage ./mdv { };
}
//
  pkgs.lib.optionalAttrs
    (builtins.elem pkgs.stdenv.hostPlatform.system [
      "aarch64-darwin"
      "x86_64-linux"
    ])
    rec {
      indexion = pkgs.callPackage ./indexion { };
      workspace = pkgs.callPackage ./workspace { inherit indexion; };
    }
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  orca-ide = pkgs.callPackage ./orca-ide { };
}
