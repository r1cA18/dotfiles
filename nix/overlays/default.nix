# Custom overlays
{
  additions = final: prev: import ../pkgs (prev // { inherit (final) callPackage; });
}
