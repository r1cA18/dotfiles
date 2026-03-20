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

    # Stitch skills
    stitch-skills.url = "github:google-labs-code/stitch-skills";
    stitch-skills.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      agent-skills-nix,
      nix-index-database,
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
    in
    {
      # Custom packages
      packages = forAllSystems (system: import ./nix/pkgs nixpkgs.legacyPackages.${system});

      # Formatter for nix files
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

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

      # OpenClaw VM configuration
      # Build with: nh home switch . -c openclaw@linux
      homeConfigurations."openclaw@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          username = "openclaw";
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
