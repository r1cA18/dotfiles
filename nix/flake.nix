{
  description = "r1ca18's cross-platform Nix configuration (macOS & Linux)";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Stable nixpkgs (for specific packages if needed)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-24.05";

    # nix-darwin (macOS only)
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # agent-skills-nix (declarative Agent Skills management)
    agent-skills-nix.url = "github:Kyure-A/agent-skills-nix";
    agent-skills-nix.inputs.nixpkgs.follows = "nixpkgs";
    agent-skills-nix.inputs.home-manager.follows = "home-manager";

    # nix-index-database (for comma)
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Anthropic official skills
    anthropic-skills.url = "github:anthropics/skills";
    anthropic-skills.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nix-darwin,
    home-manager,
    agent-skills-nix,
    nix-index-database,
    anthropic-skills,
    ...
  } @ inputs: let
    # Supported systems (macOS + Linux)
    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Your username and hostname
    username = "r1ca18";
    hostname = "RMB";
  in {
    # Custom packages
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

    # Formatter for nix files
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

    # Custom overlays
    overlays = import ./overlays {inherit inputs;};

    # Reusable darwin modules
    darwinModules = import ./modules/darwin;

    # Reusable home-manager modules
    homeManagerModules = import ./modules/home-manager;

    # Darwin configuration (macOS)
    # Build with: darwin-rebuild switch --flake .#RMB
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs username hostname;};
      modules = [
        # Main darwin configuration
        ./darwin/configuration.nix

        # home-manager darwin module
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = {inherit inputs username;};
            users.${username} = {
              imports = [
                agent-skills-nix.homeManagerModules.default
                nix-index-database.homeModules.nix-index
                (import ./home-manager/home.nix)
              ];
            };
          };
        }
      ];
    };

    # Standalone home-manager configuration (Linux/Ubuntu)
    # Build with: home-manager switch --flake .#r1ca18@linux
    homeConfigurations."${username}@linux" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {inherit inputs username;};
      modules = [
        agent-skills-nix.homeManagerModules.default
        nix-index-database.homeModules.nix-index
        ./home-manager/home.nix
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            self.overlays.additions
            self.overlays.modifications
            self.overlays.stable-packages
          ];
        }
      ];
    };

    # OpenClaw VM configuration
    # Build with: home-manager switch --flake .#openclaw@linux
    homeConfigurations."openclaw@linux" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {inherit inputs; username = "openclaw";};
      modules = [
        agent-skills-nix.homeManagerModules.default
        nix-index-database.homeModules.nix-index
        ./home-manager/home.nix
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            self.overlays.additions
            self.overlays.modifications
            self.overlays.stable-packages
          ];
        }
      ];
    };
  };
}
