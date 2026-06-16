{
  description = "r1ca18's cross-platform Nix configuration (macOS & Linux)";

  nixConfig = {
    extra-substituters = [ "https://r1ca18.cachix.org" ];
    extra-trusted-public-keys = [ "r1ca18.cachix.org-1:1QuS/Gqqw3o1atOCkrgl+5hQoLlEvTiRN8OwQT6e6lc=" ];
  };

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

    # SuperClaude Framework (agent/command definitions, cherry-picked via superclaude.nix)
    superclaude.url = "github:SuperClaude-Org/SuperClaude_Framework";
    superclaude.flake = false;

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
        "x86_64-darwin"
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
      # Skill pack library for per-project skill/plugin management.
      # Usage in project flake.nix:
      #   inputs.dotfiles.url = "git+file:///Users/r1ca18/dotfiles";
      #   devShells.default = dotfiles.lib.${system}.mkShellWithSkills {
      #     selectedPacks = [ "swift" ];
      #   };
      mkSkillPacksLib =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          asLib = import "${agent-skills-nix}/lib" {
            inherit (nixpkgs) lib;
            inherit inputs;
          };
          sources = {
            custom = {
              path = ./agents/skills;
              filter.maxDepth = 1;
            };
            anthropic = {
              path = inputs.anthropic-skills;
              subdir = "skills";
            };
            difit = {
              path = inputs.difit-skills;
              subdir = "skills";
            };
            app-store-screenshots = {
              path = inputs.app-store-screenshots;
              subdir = "skills";
            };
            notebooklm-skill = {
              path = inputs.notebooklm-skill;
            };
            typst-skills = {
              path = inputs.typst-skills;
            };
            lottie = {
              path = inputs.lottie;
              subdir = "skills";
            };
          };
          packsLib = import ./nix/lib/skill-packs.nix {
            inherit (nixpkgs) lib;
            inherit pkgs asLib sources;
          };
          devShellLib = import ./nix/lib/dev-shell.nix {
            inherit pkgs;
            inherit (packsLib) mkProjectShellHook;
          };
        in
        packsLib // devShellLib;

    in
    {
      # Skill packs library (per-project skill/plugin management)
      lib = forAllSystems mkSkillPacksLib;

      # Custom packages
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          isDarwin = builtins.elem system [
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          mkGithubReleaseApp = pkgs.callPackage ./nix/lib/github-app.nix { };
        in
        import ./nix/pkgs pkgs
        // nixpkgs.lib.optionalAttrs isDarwin {
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
        in
        {
          fmt = {
            type = "app";
            program = "${(treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix).config.build.wrapper}/bin/treefmt";
          };
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

      # Standalone home-manager configuration (Linux/Ubuntu)
      # Build with: nh home switch . -c r1ca18@linux
      homeConfigurations."r1ca18@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          username = "r1ca18";
          hostname = null;
        };
        modules = [
          agent-skills-nix.homeManagerModules.default
          nix-index-database.homeModules.nix-index
          ./nix/home-manager/home.nix
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
