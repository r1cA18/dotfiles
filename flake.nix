{
  description = "r1ca18's cross-platform Nix configuration (macOS & Linux)";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin (macOS only)
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # agent-skills-nix (declarative Agent Skills management)
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # nix-index-database (for comma)
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Anthropic official skills
    anthropic-skills.url = "github:anthropics/skills";
    anthropic-skills.flake = false;

    # difit skills
    difit-skills.url = "github:yoshiko-pg/difit";
    difit-skills.flake = false;

    # App Store screenshot generation skill
    app-store-screenshots.url = "github:ParthJadhav/app-store-screenshots";
    app-store-screenshots.flake = false;

    # NotebookLM integration skill (query notebooks from Claude Code)
    notebooklm-skill.url = "github:PleasePrompto/notebooklm-skill";
    notebooklm-skill.flake = false;

    # Typst document authoring skills
    typst-skills.url = "github:apcamargo/typst-skills";
    typst-skills.flake = false;

    # taste-skill: anti-slop frontend skill collection (13 variants)
    taste-skill.url = "github:Leonxlnx/taste-skill";
    taste-skill.flake = false;

    # text-to-lottie: author Lottie (Bodymovin) animations in a local skia player
    lottie.url = "github:diffusionstudio/lottie";
    lottie.flake = false;

    # Codex plugin: ask local Claude Code from Codex
    claude-plugin-codex.url = "github:yanchuk/claude-plugin-codex";
    claude-plugin-codex.flake = false;

    # treefmt-nix (unified formatter)
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    # git-hooks.nix (pre-commit hooks)
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      agent-skills-nix,
      nix-index-database,
      treefmt-nix,
      git-hooks-nix,
      ...
    }@inputs:
    let
      # Supported systems (macOS + Linux)
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      # Helper to build a darwin configuration
      mkDarwinConfig =
        {
          hostname,
          username,
          system ? "aarch64-darwin",
          nixEnable ? true,
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              username
              hostname
              system
              nixEnable
              ;
          };
          modules = [
            ./nix/darwin/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = { inherit inputs username hostname; };
                users.${username} = {
                  imports = [
                    agent-skills-nix.homeManagerModules.default
                    nix-index-database.homeModules.nix-index
                    (import ./nix/home-manager/home.nix)
                  ];
                };
              };
            }
          ];
        };
      # Backwards-compatible project dev-shell helper.
      # Usage in project flake.nix:
      #   inputs.dotfiles.url = "git+file:///Users/r1ca18/dotfiles";
      #   devShells.default = dotfiles.lib.${system}.mkShellWithSkills { };
      mkDevShellLib =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./nix/lib/dev-shell.nix { inherit pkgs; };

    in
    {
      # Small project dev-shell helper. Agent skills are managed globally.
      lib = forAllSystems mkDevShellLib;

      # Custom packages
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          mkGithubReleaseApp = pkgs.callPackage ./nix/lib/github-app.nix { };
        in
        import ./nix/pkgs pkgs
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          recordly = pkgs.callPackage ./nix/pkgs/recordly { inherit mkGithubReleaseApp; };
        }
      );

      # treefmt (unified formatting)
      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix;
        in
        treefmtEval.config.build.wrapper
      );

      # Flake checks (treefmt + git-hooks)
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix;
          hooks = git-hooks-nix.lib.${system}.run {
            src = ./.;
            hooks = {
              treefmt = {
                enable = true;
                package = treefmtEval.config.build.wrapper;
              };
              deadnix.enable = true;
              statix.enable = true;
            };
          };
        in
        {
          formatting = treefmtEval.config.build.check self;
          pre-commit = hooks;
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          homelab =
            pkgs.runCommand "homelab-check"
              {
                nativeBuildInputs = [
                  pkgs.ansible
                  pkgs.ansible-lint
                  pkgs.shellcheck
                ];
              }
              ''
                export HOME="$TMPDIR"
                shellcheck ${./homelab/scripts}/*.sh
                cd ${./homelab/ansible}
                ansible-playbook --syntax-check -i inventory.yml playbook.yml
                ansible-lint --offline playbook.yml
                touch "$out"
              '';
        }
      );

      # Dev shell with pre-commit hooks
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix;
          hooks = git-hooks-nix.lib.${system}.run {
            src = ./.;
            hooks = {
              treefmt = {
                enable = true;
                package = treefmtEval.config.build.wrapper;
              };
              deadnix.enable = true;
              statix.enable = true;
            };
          };
        in
        {
          default = pkgs.mkShell {
            inherit (hooks) shellHook;
            buildInputs = hooks.enabledPackages ++ [
              treefmtEval.config.build.wrapper
            ];
          };
        }
      );

      # Flake apps
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          homelabManager = pkgs.writeShellApplication {
            name = "homelab";
            runtimeInputs = [
              pkgs.ansible
              home-manager.packages.${system}.default
            ];
            text = builtins.readFile ./homelab/scripts/manage.sh;
          };
          mkHomelabApp = action: {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "homelab-${action}";
                runtimeInputs = [ homelabManager ];
                text = ''
                  exec homelab ${action} "$@"
                '';
              }
            }/bin/homelab-${action}";
            meta.description = "Run the homelab ${action} workflow";
          };
        in
        {
          fmt = {
            type = "app";
            program = "${(treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix).config.build.wrapper}/bin/treefmt";
            meta.description = "Format the dotfiles repository";
          };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          homelab-apply = mkHomelabApp "apply";
          homelab-start = mkHomelabApp "start";
          homelab-stop = mkHomelabApp "stop";
          homelab-rdp-setup = mkHomelabApp "rdp-setup";
          homelab-doctor = mkHomelabApp "doctor";
        }
      );

      # Custom overlays
      overlays = import ./nix/overlays;

      # Darwin configurations (macOS)
      # Build with: nh darwin switch . -H <hostname>
      darwinConfigurations = {
        RMB = mkDarwinConfig {
          hostname = "RMB";
          username = "r1ca18";
        };
        r1ca18lab = mkDarwinConfig {
          hostname = "r1ca18lab";
          username = "r1ca18lab";
          nixEnable = false;
        };
      };

      # Standalone Home Manager configuration used by homelab-apply.
      homeConfigurations."r1ca18@homelab" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          username = "r1ca18";
          hostname = "homelab";
        };
        modules = [
          agent-skills-nix.homeManagerModules.default
          nix-index-database.homeModules.nix-index
          ./nix/home-manager/hosts/homelab.nix
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              self.overlays.additions
            ];
          }
        ];
      };

    };
}
