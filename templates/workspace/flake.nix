{
  description = "Shared multi-repository workspace tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f0e996ff59c7624eba9db8972e8f1623a69d3b83";
  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bun
              git
              ghq
              ripgrep
              jq
              direnv
              (callPackage ./nix/indexion.nix { })
            ];
          };
        }
      );
    };
}
