# Shared formatter and hooks for checks and the development shell.
{
  inputs,
  pkgs,
  system,
}:
let
  treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../treefmt.nix;
  hooks = inputs.git-hooks-nix.lib.${system}.run {
    src = inputs.self;
    hooks = {
      treefmt = {
        enable = true;
        package = treefmt.config.build.wrapper;
      };
      deadnix.enable = true;
      statix.enable = true;
    };
  };
in
{
  formatter = treefmt.config.build.wrapper;
  checks = {
    formatting = treefmt.config.build.check inputs.self;
    pre-commit = hooks;
  }
  // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
    server =
      pkgs.runCommand "server-check"
        {
          nativeBuildInputs = [
            pkgs.ansible
            pkgs.ansible-lint
            pkgs.shellcheck
          ];
        }
        ''
          export HOME="$TMPDIR"
          shellcheck ${../../server/scripts}/*.sh
          cd ${../../server/ansible}
          ansible-playbook --syntax-check -i inventory.yml playbook.yml
          ansible-lint --offline playbook.yml
          touch "$out"
        '';
  };
  devShells.default = pkgs.mkShell {
    inherit (hooks) shellHook;
    buildInputs = hooks.enabledPackages ++ [ treefmt.config.build.wrapper ];
  };
}
